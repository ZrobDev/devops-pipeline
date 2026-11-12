# Runbook

## The daily loop

| Step | Where | What |
|---|---|---|
| 1 | laptop | Branch from `main`. Conventional Commits with a scope. |
| 2 | laptop | `/delegate-review` before opening the PR; add `/delegate-security` when the diff touches auth, secrets, network exposure or CI. |
| 3 | laptop | `/finish-feature` lints, tests, pushes, opens the PR. |
| 4 | GitHub | **Security** check runs (gitleaks, zizmor, plus semgrep/trivy where enabled). **Codex** reviews automatically. Different model family from the one that wrote the code: that is the point. |
| 5 | GitHub | Want a rules-aware second pass? Comment `@claude` on the PR. Owner only; it comments, it never pushes. |
| 6 | laptop | Red check → `/ci-triage` in the repo. It reads the failed log and proposes a fix; you decide. |
| 7 | you | Merge after green. **Agents never run `gh pr merge`**: it is denied in Claude and OpenCode settings. Checks are advisory on GitHub Free private repos, so you are the gate. |
| 8 | laptop | Delete the branch locally and on the remote. |

## When a check is red

**gitleaks.** A finding is a secret in history until proven otherwise.
1. Look at it: `gitleaks git --no-banner -v --redact .` locally.
2. Real secret: **rotate it first** (revoke at the provider), then rewrite
   history if the repo will ever be shared. Rotation is what makes you safe;
   the rewrite is cleanup.
3. False positive: add its fingerprint to `.gitleaksignore` with a comment
   saying why. Never pass `--config`; gitleaks auto-loads the repo's root
   `.gitleaks.toml` and `.gitleaksignore`.

**zizmor.** Almost always one of:
- `unpinned-uses`: replace `actions/x@vN` with
  `actions/x@<sha> # vN`. Resolve: `gh api repos/actions/x/git/ref/tags/vN -q .object.sha`
  (if `.object.type` is `tag`, dereference with `gh api repos/actions/x/git/tags/<sha> -q .object.sha`).
- `artipacked`: add `with: { persist-credentials: false }` to `actions/checkout`.
- `excessive-permissions`: add top-level `permissions: { contents: read }`.
- `template-injection`: move `${{ … }}` out of `run:` into `env:`.

**semgrep.** Only `ERROR` fails the job; `WARNING` shows in the step summary.
Fix the code. If it is truly a false positive, a `# nosemgrep: <rule-id>`
comment on the line, with the reason.

**trivy.** CRITICAL/HIGH in a dependency: bump it (Dependabot often already
has the PR). No fix available: the gate skips it (`--ignore-unfixed`); it
resurfaces as soon as a fixed version is published.

## Dependabot

- Alerts: on for every non-archived repo (`rollout.sh` enables them).
- Version-update PRs: active repos only, weekly, grouped per ecosystem, at most
  5 open per ecosystem, 7-day cooldown so a bad release gets yanked before it
  reaches you.
- No AI review on Dependabot PRs. The Security check is enough; merge in
  batches.

## Adding a repo or changing the suite

- New repo: `scripts/rollout.sh --repo NAME` (dry run), then add `--apply`, then merge the PR.
- Python repo: add `templates/python-ci-caller.yml` as `.github/workflows/ci.yml`
  (pull_request only; needs `uv.lock`, `ruff: false` without ruff in the dev group).
- Deploying to a tailnet host: `docs/deploy-tailscale-ssh.md`.
- Changing a reusable workflow here: PR → `selftest` green → merge → move the tag:
  `git fetch origin && git tag -f v1 origin/main && git push -f origin v1`.
  Every caller picks it up on its next run. A bad `v1` breaks every repo at
  once: selftest has to be green before moving the tag.
- Bumping a pinned tool: update the version and checksum in `security.yml`
  **and** `selftest.yml` (they are in lockstep), resolving the checksum with
  `gh release download vX -R owner/repo -p '*checksums.txt' -O - | grep <asset>`.

## Rotations

See `setup-secrets.md`. The Claude token expires a year after it is generated.
