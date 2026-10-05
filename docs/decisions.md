# Decisions

Settled by a grilling session on 2026-10-04. Supersedes the 2026-09-04 plan
(`~/.claude/plans/wise-mapping-parrot.md`, approved, never executed): its tool
choices, its "dropped" list and its YAML were carried over. What changed: the
home repo is this one (not `ci-templates`), there are 34 non-archived private
repos (31 active), an on-demand Claude reviewer was added, and the client v2
doc was dropped.

## The stack

| Layer | Choice | Cost |
|---|---|---|
| Secrets | gitleaks, full history, every repo, hard fail. Checksum-verified release binary, not `gitleaks-action` (which downloads its binary unverified). | $0 |
| Workflow lint | zizmor, every repo, medium+ fails. | $0 |
| SAST | Semgrep CE `p/security-audit`, Python/TS repos, only ERROR fails. | $0 |
| Dependencies | Dependabot alerts on every repo; version-update PRs only on active repos. Trivy (pinned binary) where lockfiles, Dockerfiles or compose files exist; CRITICAL/HIGH with a fix available fails (`--ignore-unfixed`: a CVE with no fixed version is unactionable, so it is not part of the bar). | $0 |
| AI review, automatic | Codex connector (ChatGPT Plus), on open / ready-for-review. | already paid |
| AI review, on demand | `anthropics/claude-code-action` on the Claude subscription (`CLAUDE_CODE_OAUTH_TOKEN`), fired by an owner's `@claude` comment. Comment-only. | already paid |
| Local | `/delegate-review`, `/delegate-security`, `/finish-feature`, `/ci-triage`, pre-push gitleaks hook. | flat plans |
| Merge gate | You. GitHub Free private repos cannot enforce checks. | $0 |

## Why each decision

- **One repo for the suite.** One version tag, one place to look. Callers pin
  `@v1`, a moving tag on a repo only you can push to. SHA-pinning your own
  private template is maintenance without security. Third-party actions are
  always SHA-pinned.
- **Codex automatic, Claude on demand.** Most code here is written by Claude.
  A reviewer from the same model family shares its blind spots, so the
  automatic first review is a different family (GPT). Claude's pass earns its
  place by checking conformance with `AGENTS.md` and repo rules, and is
  on demand so it cannot drain the subscription you code with.
- **Claude is comment-only.** With push rights, any text in a PR (diff, body,
  a dependency's README) becomes a prompt-injection path into a job holding a
  write token. Enforced by the token (`contents: read`), not by the prompt.
  The prompt is fixed, so comment text is a trigger, never instructions.
- **Tiers.** All repos get the security gates; only active repos get AI review,
  Dependabot PRs and the token. Dormant repos produce alerts, not PRs.
- **Stay on GitHub Free.** Pro ($4/mo) would buy branch protection on private
  repos. Merges happen only on your laptop, so you are the gate already.
  Revisit the day a red merge happens or a second human gets push.
- **Debugging is local.** `/ci-triage` costs no Actions minutes and no quota.
  CI auto-triage would spend both on every red run.

## Rejected, and why

| Option | Why not |
|---|---|
| Qodo (SaaS, formerly Qodo Merge) | Pricing page (2026-10-04) shows only a trial; self-hosting is Enterprise-only; another third party reading private code. "Self-hosted Qodo" in practice is PR-Agent, below. |
| SonarQube Cloud | Free tier exists (50k LOC), but another third party with private-code read; ruff/shellcheck cover the estate. |
| CodeRabbit | Free tier on private repos is summaries only. Uninstall after the trial. |
| `trivy-action` / `setup-trivy` | Compromised 2026-02-28 and 2026-03-19 (GHSA-69fq-xp46-6x23). Binary only, checksum-pinned, from an immutable release. |
| SARIF upload / Security tab | Needs GitHub Code Security on an org Team/Enterprise plan. Findings go to the job log and step summary; the exit code is the gate. |
| Branch protection / rulesets | 403 on private repos under GitHub Free. |
| Dependabot auto security-fix PRs | Alert fatigue across 34 repos. Turn on per repo if wanted: `rollout.sh --repo NAME --security-fixes --apply`. Opted in 2026-10-04: the trivy-red repos, because version updates only start once the red rollout PR merges and dormant repos never get them. |
| CI auto-triage with Claude | Minutes and quota on every red run; `/ci-triage` does it locally. |
| Claude pushing fixes | See "comment-only" above. |

## Known gaps

- **The merge deny is a guardrail, not a boundary.** Claude Code and OpenCode deny
  `gh pr merge`, `gh <global flags> pr merge` and `gh api …merge…` (the `-R` form slipped
  past the first pattern; found in review, fixed, verified live). It stops an agent merging
  by accident or habit. It cannot stop a determined one: the gh token itself can merge, and
  a command can be spelled many ways. Codex CLI has no per-command deny at all. Do not give
  a Codex session a token that can merge.
- **zizmor `ref-confusion` is off.** It must list branches of this private repo,
  which a caller's `GITHUB_TOKEN` cannot read, and it aborts the whole run
  rather than warning. Every other online audit stays on. Config: `zizmor.yml`
  (here) and the inline copy in `security.yml` (callers).
- **A caller's own `zizmor.yml` is ignored** in CI, because `security.yml` passes `--config`.
- **No selftest job runs trivy's fail path.** `fixtures/` holds no lockfile or
  Dockerfile; `pins` only proves the binary resolves. A change to the trivy
  flags is verified by hand against a red caller (2026-10-04: `--ignore-unfixed`
  checked on 12 red repos, all still exit 1; it dropped 2 of ~200 findings).
- **Dependabot cannot read this private repo**, so it never bumps the
  `@v1` line in callers. That's fine because the tag moves.

## gh-secure

`gh extension install GitHubSecurityLab/gh-secure --pin a04d1c144f5d1b63a8aa5cd7946e8ceafa709a2a`
(HEAD of 2026-10-02; the repo has a single tag).

- `gh secure status --repo ZrobDev/<r>`: read-only audit. Run it on any repo before changing its visibility.
- `gh secure --dry-run --repo ZrobDev/<r>`: shows what it would turn on.
- What it turns on: branch protection, private vulnerability reporting, secret
  scanning with push protection, Dependabot, CodeQL. On **private repos under
  GitHub Free only Dependabot applies**, and `rollout.sh` already does that. The
  rest is the payoff for any repo you later make **public**: run
  `gh secure --repo ZrobDev/<r>` right after flipping it.

## PR-Agent (optional third reviewer, not deployed)

MIT, community-owned since Qodo donated it (v0.47.0, 2026-10-02). It needs a
pay-per-token key; subscriptions cannot back it. Turn it on only if Codex quota
runs out or Codex reviews prove shallow across 10+ PRs. Then:

- An OpenRouter key with a hard spend cap (≈$5/month) at Doppler
  `fleet/prd OPENROUTER_KEY`, pushed per repo like the Claude token.
- `/describe` only by default (cheap model); `/review` on demand.

```yaml
# .github/workflows/pr-agent.yml (caller repo)
name: PR-Agent
on:
  pull_request:
    types: [opened, ready_for_review]
permissions:
  contents: read
  pull-requests: write
  issues: write
jobs:
  pr-agent:
    if: github.event.pull_request.user.type != 'Bot'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: docker://pragent/pr-agent@sha256:31b9aac6ab067bada9a0c1b001d30ebc500ea4487e00a93c18c59b9ef5fa66db # 0.47.0-github_action
        env:
          GITHUB_TOKEN: ${{ github.token }}
          OPENROUTER.KEY: ${{ secrets.OPENROUTER_KEY }}
          CONFIG.MODEL: openrouter/<cheap-model-id>
          CONFIG.FALLBACK_MODELS: '[]'
          CONFIG.RESTRICTED_MODE: "true"
          GITHUB_ACTION_CONFIG.AUTO_DESCRIBE: "true"
          GITHUB_ACTION_CONFIG.AUTO_REVIEW: "false"
          GITHUB_ACTION_CONFIG.AUTO_IMPROVE: "false"
```

Re-verify the digest (`hub.docker.com/r/pragent/pr-agent/tags`) and the env
names against docs.pr-agent.ai before enabling.

## Facts these decisions rest on

Verified 2026-09-04 (F1–F10 in the old plan) and re-verified or added 2026-10-04:
- All ZrobDev repos are private on personal GitHub Free: 2,000 Actions minutes a month, no branch protection, no SARIF.
- Private reusable workflows are callable from the same user's private repos (Settings → Actions → Access → "repositories owned by the user"). `secrets: inherit` is org-only, so secrets are passed explicitly.
- `claude setup-token` issues a one-year OAuth token. claude-code-action v1.0.241 is commit `cab360f6565aa35a51d6ce9e43f1f4287c0a32ea`.
- Codex honors an `AGENTS.md` section named `## Code Review Rules`.
- PR-Agent supports OpenAI, Anthropic, OpenRouter, Ollama and OpenAI-compatible endpoints via LiteLLM, with no subscription OAuth.
- Pinned: gitleaks 8.30.1, trivy 0.74.0, zizmor 1.30.0, semgrep 1.176.1, actions/checkout v7.0.1 (`3d3c42e5…`). Newer releases existed at rollout (zizmor 1.30.1, semgrep 1.179.0, trivy 0.75.0); bump via the runbook procedure.
