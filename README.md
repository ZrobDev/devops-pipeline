# devops-pipeline

Code review, PR review, security review and CI debugging for every ZrobDev
repo, on free tools and subscriptions already paid for.

| Want to… | Go to |
|---|---|
| Know the daily loop, or fix a red check | [docs/runbook.md](docs/runbook.md) |
| Set up or rotate the Claude token; enable Codex review | [docs/setup-secrets.md](docs/setup-secrets.md) |
| Know why it is built this way, what was rejected, PR-Agent, gh-secure | [docs/decisions.md](docs/decisions.md) |
| Roll the suite out to a repo | `scripts/rollout.sh --help` (dry run by default) |

## What a repo gets

| Tier | Gets |
|---|---|
| Active (pushed within 90 days) | `Security` workflow, `@claude` review workflow, Dependabot version updates, `## Code Review Rules` in `AGENTS.md`, Codex automatic review |
| Dormant | `Security` workflow, Dependabot alerts |
| Archived | nothing |

## Layout

- `.github/workflows/security.yml`: reusable gate (gitleaks, zizmor, optional semgrep/trivy).
- `.github/workflows/claude-review.yml`: reusable, comment-only Claude review.
- `.github/workflows/selftest.yml`: proves the gates fail on `fixtures/`, audits the templates.
- `templates/`: what `rollout.sh` copies into each repo.
