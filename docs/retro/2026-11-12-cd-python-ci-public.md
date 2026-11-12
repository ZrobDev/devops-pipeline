# Retro: cd-python-ci-public

- Date: 2026-11-12
- Repo: ZrobDev/devops-pipeline · Branch: main · Range: 26eeabf..0b97dbb (4 commits since 2026-10-04)
- Previous: [2026-10-04-handoff-open-items.md](2026-10-04-handoff-open-items.md)
- Backlog: yes

## State
- #11 feat: reusable `python-ci.yml`, `deploy-tailscale-ssh.yml`, four templates, `docs/deploy-tailscale-ssh.md` — merged — released v1.1.0
- #13 fix(python-ci): `uv sync --frozen --all-groups --all-extras` — merged — released v1.1.1; `v1` -> v1.1.1
- Repo visibility PUBLIC; rulesets `main: PR only, no force push` and `release tags immutable (v1 floating tag excluded)` active; secret scanning + push protection enabled
- Issue #12: eight low-severity hygiene items from the cross-repo workflow review — open
- Callers live: hermes-personalization `deploy.yml` (four dispatches, last two green), financial-report-generator `ci.yml` (python-ci green), data-engineering-skills and devops-skills call `security.yml@v1` from public repos

## Deviations
| Plan said | What was done | Why | Asked |
|---|---|---|---|
| Deploy over Tailscale with an OAuth client secret in GitHub | OIDC federated identity (`oauth-client-id` + `audience` inputs, repository variables, no secret) | both Tailscale actions accept a federated identity; one credential fewer to rotate | no, reported same turn |
| Signed tags (`git tag -s`) | annotated unsigned tags | no signing key configured in this clone (`gpg: No secret key`); signing config is a workstation concern | no |
| Move `v1` once, after v1.1.0 | moved twice (v1.1.0, then v1.1.1) | the first caller exposed the extras bug; fix needed a release | yes, both moves |
| Pilot CI on `financial-report-generator` via `rollout.sh` | only the `python-ci` caller was added | the repo already had security, claude and dependabot from an earlier rollout; local clone was behind | no |

## Owed
- [ ] operator: `gh issue view 12` — pick the first two items (step-scoped `GH_TOKEN`, drop `Bash(gh pr comment:*)`) for a hygiene PR
- [ ] operator: decide the NOTES.md dependabot question below (exempt security updates from the 7-day cooldown, or keep manual uv-lock PRs) and record it in `docs/decisions.md`
- [ ] operator: delete the absorbed lines from `docs/retro/NOTES.md` is done by this retro; commit `docs/retro/` on a branch

## Verification loop
```bash
gh repo view --json visibility --jq .visibility                                   # PUBLIC
git ls-remote --tags origin | grep -E 'refs/tags/v1\^\{\}$' | cut -c1-7              # 0b97dbb (v1 = v1.1.1)
gh api repos/ZrobDev/devops-pipeline/rulesets --jq length                          # 2
gh run list --workflow selftest --branch main --limit 1 --json conclusion --jq '.[0].conclusion'   # success
uv tool run --from 'zizmor==1.30.0' zizmor --min-severity medium --format plain --color never .github/workflows templates | tail -1   # No findings to report (pin = ZIZMOR_VERSION in security.yml; local 1.31.1 flags claude.yml issue_comment as dangerous-triggers)
```

## Failure modes
| What broke | Where it hid | Root cause | Check that now forces it |
|---|---|---|---|
| First `python-ci` caller: `Failed to spawn: ruff` | `python-ci.yml` `uv sync --frozen` | dev tools declared as a `[project.optional-dependencies]` extra, which `uv sync` skips; other repos use `[dependency-groups]` | `grep -q -- '--all-groups --all-extras' .github/workflows/python-ci.yml` |
| `gh run rerun --failed` after moving `v1` ran the old reusable code | caller run 43160244062 | a rerun reuses the original run's resolved refs | `review: after a tag move, was a new commit pushed instead of a rerun?` |
| Required-status-check names broke on a caller that switched to the reusable gate | data-engineering-skills ruleset `main-protection` | contexts were the old inline job names (`gitleaks`), reusable jobs report as `security / gitleaks` | `gh api repos/ZrobDev/<repo>/rulesets --jq '.[].id' \| xargs -I{} gh api repos/ZrobDev/<repo>/rulesets/{} --jq '.rules[]?.parameters.required_status_checks[]?.context' \| grep -c '^security / '` ≥ 2 |

## Process lessons
- Evidence: #13. Rule: a new reusable workflow gets a real caller on a branch before its release tag moves; `v1` moves only after that caller is green. Scope: project.
- Evidence: run 43160244062. Rule: after `git push -f origin v1`, verify with a fresh push to a caller, never `gh run rerun`. Scope: global-candidate.
- Evidence: NOTES.md 2026-10-04 lines. Rule: `grep -n cooldown templates/dependabot.yml` before blaming a missing security bump; the cooldown holds security versions inside grouped PRs. Scope: project.

## Decisions
- Kept: callers pin `@v1`, third parties by SHA — a public repo makes the floating tag the one way to ship a fix to 14 callers at once (`AGENTS.md`)
- Kept: `python-ci` runs on `pull_request` only — Actions minutes were 711/2000 on Nov 11 (plan `how-could-i-use-velvety-galaxy.md`)
- Reversed: deploy auth from a stored OAuth secret → OIDC federated identity — nothing to rotate (Deviations row 1)
- Dropped: an LLM `ci-reviewer` agent — a dry run over 13 repos found 0 high/medium, 8 low; zizmor covers the high-impact classes (issue #12)
- Dropped: `rsync`/`tmate`/`first-interaction` patterns from the Link-/ci-cd-intro sample — `templates/` keep only OIDC, environments, plan-as-comment (plan)

## Memory proposals
| Action | Note | Reason |
|---|---|---|
| update | cicd-upgrade-state-2026-11.md | record v1.1.1, public, rulesets, the four hermes runs, and that retros are written |

Status: applied 2026-11-12

## Skill feedback
| Skill | Repo | What the agent did | What it should have done | Evidence | Issue |
|---|---|---|---|---|---|
| release | ZrobDev/devops-skills | procedure says `git tag -s`; this clone has no signing key, so the step would fail | say "sign if a key is configured, else annotated `-a`, and record which" | this retro, Deviations row 2 | https://github.com/ZrobDev/devops-skills/issues/4 |

Status: applied 2026-11-12

## Graduation candidates
- `after moving a floating tag, push a commit to a caller; never gh run rerun` — test: 2 projects: devops-pipeline run 43160244062 only → fails test (one project so far)

## Next session
1. `/retro apply` (memory proposal, skill feedback row, graduation check)
2. Verification loop above
3. Hygiene PR from issue #12, items 1 and 2
4. `docs/decisions.md`: dependabot cooldown vs security updates (NOTES.md 2026-10-04)

Suggested skills: gha-author, release, ci-triage
