#!/usr/bin/env bash
# Roll the devops-pipeline suite out to ZrobDev repos. Dry run by default.
#
#   scripts/rollout.sh                          # plan for every repo, writes nothing
#   scripts/rollout.sh --repo NAME --apply      # one repo
#   scripts/rollout.sh --tier active --apply    # a wave
#   scripts/rollout.sh --secrets-only --apply   # (re)push the Claude token = rotation
#   scripts/rollout.sh --repo NAME --security-fixes --apply   # opt one repo into fix PRs, nothing else
#
# Tiers: archived -> skipped; pushed within 90 days -> active (full suite);
# else dormant (security gates + Dependabot alerts, no AI review, no secret).
#
# Per repo it: enables Dependabot alerts (security-fix PRs only with
# --security-fixes, one --repo at a time: docs/decisions.md); pushes the Claude
# token from Doppler (active only, over stdin, never argv or logs); clones,
# counts gitleaks history hits and zizmor findings (reports only, never writes
# an allowlist); adds the tier's files on branch ci/devops-pipeline; opens a PR.
# It NEVER merges. Re-running is safe: existing files, secrets and PRs are skipped.
set -euo pipefail

OWNER=ZrobDev
BRANCH=ci/devops-pipeline
DOPPLER_PROJECT=fleet
DOPPLER_CONFIG=prd
SECRET=CLAUDE_CODE_OAUTH_TOKEN
ZIZMOR=zizmor@1.30.0   # keep in lockstep with security.yml

APPLY=0 SECRETS_ONLY=0 FIXES=0 ONLY_REPO="" ONLY_TIER=""
while (($#)); do
  case "$1" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --secrets-only) SECRETS_ONLY=1 ;;
    --security-fixes) FIXES=1 ;;
    --repo) ONLY_REPO="${2:?--repo needs a name}"; shift ;;
    --tier) ONLY_TIER="${2:?--tier needs active|dormant}"; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done
[[ -z "$ONLY_TIER" || "$ONLY_TIER" == active || "$ONLY_TIER" == dormant ]] || { echo "--tier must be active or dormant" >&2; exit 2; }
# Fix PRs are opt-in per repo (alert fatigue fleet-wide): never for a wave or a rotation.
if ((FIXES)) && [[ -z "$ONLY_REPO" ]] || ((FIXES && SECRETS_ONLY)); then
  echo "--security-fixes needs --repo NAME and no --secrets-only" >&2; exit 2
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$HERE/templates"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
CUTOFF="$(date -u -d '90 days ago' +%FT%TZ)"

if ((APPLY)) && [[ "$ONLY_TIER" != dormant ]]; then
  # Fail before touching any repo, not halfway through a wave. Dormant repos never get the token.
  doppler secrets get "$SECRET" --plain --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" >/dev/null \
    || { echo "Doppler has no $SECRET in $DOPPLER_PROJECT/$DOPPLER_CONFIG; see docs/setup-secrets.md" >&2; exit 1; }
fi
command -v gitleaks >/dev/null || echo "note: gitleaks not installed, history column will read n/a" >&2

push_secret() {  # value goes doppler -> gh over a pipe; it never touches argv, a var or stdout
  doppler secrets get "$SECRET" --plain --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" \
    | gh secret set "$SECRET" -R "$OWNER/$1" >/dev/null
}

add_file() {  # add_file SRC DEST: copy unless DEST exists; records what happened
  if [[ -e "$DEST_ROOT/$2" ]]; then SKIPPED+=("$2"); return; fi
  mkdir -p "$(dirname "$DEST_ROOT/$2")"; cp "$1" "$DEST_ROOT/$2"; ADDED+=("$2")
}

row() { printf '%-34s %-8s %-9s %-9s %-6s %-6s %s\n' "$@"; }

has() { [[ -n "$(find "$DEST_ROOT" -maxdepth 3 -path "$DEST_ROOT/.git" -prune -o -type f \( "$@" \) -print -quit)" ]]; }

row REPO TIER ALERTS SECRET LEAKS ZIZMOR RESULT
gh repo list "$OWNER" --limit 200 --json name,pushedAt,isArchived,defaultBranchRef \
  -q '.[] | [.name, .pushedAt, .isArchived, (.defaultBranchRef.name // "")] | @tsv' | sort |
while IFS=$'\t' read -r repo pushed archived default; do
  [[ -n "$ONLY_REPO" && "$repo" != "$ONLY_REPO" ]] && continue
  if [[ "$archived" == true ]]; then tier=archived; elif [[ "$pushed" > "$CUTOFF" ]]; then tier=active; else tier=dormant; fi
  [[ -n "$ONLY_TIER" && "$tier" != "$ONLY_TIER" ]] && continue
  if [[ "$tier" == archived || -z "$default" ]]; then
    row "$repo" "$tier" - - - - "skipped (${default:+archived}${default:-empty repo})"; continue
  fi

  # Dependabot alerts: free on private repos, alerts only. A rotation touches secrets and nothing else.
  if ((SECRETS_ONLY)); then alerts=-
  elif ((APPLY)); then gh api -X PUT --silent "repos/$OWNER/$repo/vulnerability-alerts" </dev/null && alerts=on || alerts=FAILED
  else alerts=would-on; fi
  if ((FIXES)); then  # state is re-read after the PUT: a paused repo may stay paused
    fixes() { gh api "repos/$OWNER/$repo/automated-security-fixes" -q 'if .enabled then (if .paused then "paused" else "on" end) else "off" end' </dev/null 2>/dev/null || echo ERR; }
    was="$(fixes)"
    if ((APPLY)); then gh api -X PUT --silent "repos/$OWNER/$repo/automated-security-fixes" </dev/null && alerts+=" fixes:$was>$(fixes)" || alerts+=" fixes:$was>FAILED"
    else alerts+=" fixes:$was>would-on"; fi
  fi

  # Claude token: active tier only. --secrets-only overwrites (rotation); otherwise set only if missing.
  secret=-
  if [[ "$tier" == active ]] && ((!FIXES)); then
    if gh secret list -R "$OWNER/$repo" --json name -q '.[].name' </dev/null | grep -qx "$SECRET" && ((!SECRETS_ONLY)); then secret=exists
    elif ((APPLY)); then push_secret "$repo" </dev/null && secret="set" || secret=FAILED
    else secret=would-set; fi
  fi

  if ((SECRETS_ONLY)); then
    row "$repo" "$tier" "$alerts" "$secret" - - "secrets-only"; continue
  fi
  if ((FIXES)); then row "$repo" "$tier" "$alerts" - - - "security-fixes only"; continue; fi
  # git/ref takes the slash in the branch name as-is. A branch with no open PR is
  # a run that died between push and `gh pr create`, or a closed PR: say so.
  if gh api --silent "repos/$OWNER/$repo/git/ref/heads/$BRANCH" >/dev/null 2>&1 </dev/null; then
    pr="$(gh pr list -R "$OWNER/$repo" --head "$BRANCH" --state open --json url -q '.[0].url' </dev/null)"
    if [[ -n "$pr" ]]; then note="exists: $pr"
    else note="STALE branch $BRANCH, no open PR: delete it (gh api -X DELETE repos/$OWNER/$repo/git/refs/heads/$BRANCH) and re-run"; fi
    row "$repo" "$tier" "$alerts" "$secret" - - "$note"; continue
  fi

  DEST_ROOT="$WORK/$repo"
  gh repo clone "$OWNER/$repo" "$DEST_ROOT" -- --quiet </dev/null 2>/dev/null

  leaks=n/a
  if command -v gitleaks >/dev/null; then  # full history; auto-loads the repo's own .gitleaks.toml/.gitleaksignore
    gitleaks git --no-banner --redact --exit-code 0 --log-level error --report-format json --report-path "$WORK/$repo.leaks.json" "$DEST_ROOT" </dev/null || true
    leaks="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$WORK/$repo.leaks.json" 2>/dev/null || echo ERR)"
  fi

  ADDED=() SKIPPED=()
  semgrep=false trivy=false
  has -name pyproject.toml -o -name package.json && semgrep=true
  has -name uv.lock -o -name poetry.lock -o -name 'requirements*.txt' -o -name package-lock.json -o -name pnpm-lock.yaml \
      -o -name yarn.lock -o -name bun.lock -o -name go.sum -o -name Cargo.lock -o -name Dockerfile -o -name Containerfile \
      -o -name '*.tf' -o -name 'compose*.y*ml' -o -name 'docker-compose*.y*ml' && trivy=true   # same list as security.yml's trivy job
  tools="gitleaks, zizmor"; [[ $semgrep == true ]] && tools+=", semgrep"; [[ $trivy == true ]] && tools+=", trivy"
  # `|` delimiter: a default branch may contain `/`. Then assert every edit
  # landed: a template reworded so a pattern no longer matches must stop the
  # run, not ship semgrep:false everywhere.
  sed -e "s|^      semgrep: false .*|      semgrep: $semgrep|" -e "s|^      trivy: false .*|      trivy: $trivy|" \
      -e "s|branches: \[main\]|branches: [$default]|" "$T/security-caller.yml" > "$WORK/security.yml"
  for want in "      semgrep: $semgrep" "      trivy: $trivy" "    branches: [$default]"; do
    grep -qxF "$want" "$WORK/security.yml" || { echo "template edit failed for $repo: '$want' not found" >&2; exit 1; }
  done
  add_file "$WORK/security.yml" .github/workflows/security.yml

  if [[ "$tier" == active ]]; then
    add_file "$T/claude-caller.yml" .github/workflows/claude.yml
    cp "$T/dependabot.yml" "$WORK/dependabot.yml"
    for eco in "uv:uv.lock" "npm:package-lock.json" "npm:pnpm-lock.yaml" "npm:yarn.lock" "bun:bun.lock" "docker:Dockerfile"; do
      [[ -e "$DEST_ROOT/${eco#*:}" ]] || continue
      grep -q "package-ecosystem: ${eco%%:*}$" "$WORK/dependabot.yml" && continue
      printf '  - package-ecosystem: %s\n    directory: /\n    schedule: { interval: weekly }\n    groups: { %s: { patterns: ["*"] } }\n    cooldown: { default-days: 7 }\n    open-pull-requests-limit: 5\n' \
        "${eco%%:*}" "${eco%%:*}" >> "$WORK/dependabot.yml"
    done
    add_file "$WORK/dependabot.yml" .github/dependabot.yml

    # Review rules for Codex + Claude. CLAUDE.md that is a regular-file twin of AGENTS.md gets the same append.
    if ! grep -qs '^## Code Review Rules' "$DEST_ROOT/AGENTS.md"; then
      twin=0; [[ -f "$DEST_ROOT/CLAUDE.md" && ! -L "$DEST_ROOT/CLAUDE.md" && ! "$DEST_ROOT/CLAUDE.md" -ef "$DEST_ROOT/AGENTS.md" ]] && cmp -s "$DEST_ROOT/AGENTS.md" "$DEST_ROOT/CLAUDE.md" && twin=1
      { [[ -s "$DEST_ROOT/AGENTS.md" ]] && echo; cat "$T/code-review-rules.md"; } >> "$DEST_ROOT/AGENTS.md"; ADDED+=(AGENTS.md)
      ((twin)) && cp "$DEST_ROOT/AGENTS.md" "$DEST_ROOT/CLAUDE.md" && ADDED+=(CLAUDE.md)
    fi
  fi

  # zizmor over the workflows as they will be after the PR: the first-run red wall, counted up front.
  zfind="$( (cd "$DEST_ROOT" && uvx -q "$ZIZMOR" --config "$HERE/zizmor.yml" --offline --min-severity medium --format json .github/workflows/ 2>/dev/null </dev/null || true) \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo ERR)"

  result="add: ${ADDED[*]:-nothing}${SKIPPED:+; exists: ${SKIPPED[*]}}"
  if ((${#ADDED[@]} == 0)); then result="nothing to add${SKIPPED:+ (exists: ${SKIPPED[*]})}"
  elif ((APPLY)); then
    (
      cd "$DEST_ROOT"
      git switch -q -c "$BRANCH"
      git add -- "${ADDED[@]}"
      git commit -q -m "ci(security): add devops-pipeline gates and review" \
        -m "Security gates ($tools) from ZrobDev/devops-pipeline@v1. Tier: $tier."
      git push -q -u origin "$BRANCH" </dev/null
      gh pr create --base "$default" --head "$BRANCH" --title "ci(security): add devops-pipeline gates and review" --body \
"Rolled out by \`ZrobDev/devops-pipeline/scripts/rollout.sh\` (tier: **$tier**).

Adds: ${ADDED[*]}${SKIPPED:+
Already present, not touched: ${SKIPPED[*]}}

Before merging, expect these on the first run:
- gitleaks history hits: **$leaks**. A real leak is rotated first; a fingerprint goes in \`.gitleaksignore\` only after inspection.
- zizmor findings (medium+): **$zfind**. Usually unpinned \`actions/*@vN\` in existing workflows: pin to a SHA.

The human merges. Agents never run \`gh pr merge\`. Runbook: devops-pipeline \`docs/runbook.md\`." </dev/null
    ) >"$WORK/$repo.pr.log" 2>&1 && result="PR $(grep -o 'https://github.com/[^ ]*/pull/[0-9]*' "$WORK/$repo.pr.log" | tail -1)" \
      || result="FAILED: $(tail -1 "$WORK/$repo.pr.log")"
  fi
  row "$repo" "$tier" "$alerts" "$secret" "$leaks" "$zfind" "$result"
done
