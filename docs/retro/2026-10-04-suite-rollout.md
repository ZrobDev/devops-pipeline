# Retro: suite-rollout

- Date: 2026-10-04
- Repo: ZrobDev/devops-pipeline · Branch: main · Range: 1bf1cc5..4128805 (7 commits since repo start)
- Previous: none
- Backlog: yes

## State
- devops-pipeline #1 feat(suite): reusable security gates, on-demand Claude review, rollout: merged, tagged `v1` at 86f1e0e, used by every rolled-out repo
- devops-pipeline #2 fix(rollout): hard-linked CLAUDE.md twin, plus decisions note (merge deny is a guardrail): merged
- devops-pipeline #3 ci(security): dogfood adds claude.yml and review rules to this repo: open, green
- devops-pipeline #4 fix(rollout): print an existing PR's URL once: open
- omarchy-workstation-setup #70 ci: security gates, owner-only Claude review, agents cannot merge: merged. Live: the merge deny is in `~/.claude/settings.json`; OpenCode gets it from `chezmoi apply`
- omarchy-workstation-setup #71: `@claude` smoke test, closed as intended (review posted, no push)
- omarchy-workstation-setup #72 fix(ci): rehearse path filter adds Containerfile.rehearse and rehearse.yml (Codex P1 on #70): open, green
- Wave 2 (active tier): 28 rollout PRs open, 17 fully green. Red ones are real findings: trivy CVEs in 10 repos, plus calidad-cotizador's pre-existing `docker-smoke` failure (`pnpm fetch --frozen-lockfile`)
- Wave 3 (dormant tier): amistad-crcd-cpr #1 green; astro-zrobdev-portfolio #1 red on trivy (45 HIGH, 2 CRITICAL); payroll-pipeline #20 just received a fix for its stray worktree gitlink, CI pending
- Secrets: `CLAUDE_CODE_OAUTH_TOKEN` is in Doppler fleet/prd (expiry recorded) and pushed to 30 active repos. Dependabot alerts are on for all 33 non-empty, non-archived repos

## Deviations
| Plan said | What was done | Why | Asked |
|---|---|---|---|
| zizmor `impostor-commit` on the private ref: fall back to `--offline` | Disabled only `ref-confusion` and allowed tag pins for `ZrobDev/*` via zizmor.yml, inlined in security.yml | `ref-confusion` was the audit that aborted; this keeps every other online audit | yes |
| Old-plan YAML verbatim, including `.semgrepignore` | Dropped `.semgrepignore` | It hid `fixtures/` from the must-fail step, even when named explicitly | no |
| Old-plan YAML verbatim (gitleaks `--exit-code 1`, `rc -le 1`) | Findings use exit 42, and any other non-zero fails the job | gitleaks exits 1 on its own errors, so a broken scan went green | no |
| Dependabot entries as in the old plan | Added `cooldown: 7 days` | zizmor `dependabot-cooldown` finding | no |
| selftest as in the old plan | Added a `pins` job (lockstep check, trivy checksum resolves) and shellcheck on `scripts/` | Review findings: trivy pins were never exercised | no |
| Delegate the YAML, README and script drafting to a cheap lane | The orchestrator wrote all files | Security paths dominated, and the old YAML only needed copying | no |
| delegate-review uses 9 angles | PR #70 got 4 lanes (A, B, C, combined cleanup) | Config-only PR | no |
| Pilot touches only the workflows listed in the old plan | Also pinned `pr-body.yml` | It postdated the old plan and would have turned zizmor red | no |
| `gh pr merge*` deny | Widened to `gh * pr merge*` and `gh api *merge*` (Claude), with leading-wildcard forms in OpenCode | Review: `gh -R repo pr merge` bypassed the deny | no |
| Rollout PRs add template files only | Wave 2/3 PRs also carry SHA-pin fixes for existing workflows (6 repos), `.gitleaksignore` fingerprints (5 repos), fedora `semgrep: false`, and payroll's gitlink removal | Each was needed for green gates | yes |
| Push the pilot normally | Pushed twice with `--no-verify` | gate.yaml holds `opencode.json`; `--no-verify` is the designed human confirmation | yes |
| Premise: 22 repos | 34 non-archived (31 active, 3 dormant, 1 empty) | The estate grew since 2026-09-04 | n/a |
| Premise: rehearse path filter is complete | It missed `Containerfile.rehearse` | Codex caught it on #70; fixed in #72 | n/a |

## Owed
- [ ] operator: merge devops-pipeline #3, #4 and omarchy #72. Unblocks dogfood and the correct rehearse trigger
- [ ] operator: merge the 31 rollout PRs: 2markit#10 agency-matrix-scrapper#5 amistad-crcd-cpr#1 astro-zrobdev-portfolio#1 bachelor-computer-engineering#1 calidad-cotizador#5 client-on-my-grind#2 cpr-download-automation#13 doc-eval#1 fedora-workstation-setup#66 financial-report-generator#3 hermes-dokploy-setup#3 hermes-personalization#36 lease-agreement#2 linkedin-optimizer#1 linux-vps-hardening#13 markit#7 n8n-dokploy#5 obsidian-vault#2 pay-audit#51 payroll-pipeline#20 pdf-to-md#2 pending-cancels-sheets-migration#9 pending-cancels-workflow#150 progressive-scrapper#5 proxmox-homelab-server#4 soi-renewal-automation#2 split-time-sheets#4 timesheet-travel-extractor#1 vps-claude-setup#17 whisper-transcript#4 zrob-projects-docs#1. Unblocks Dependabot version PRs and the `@claude` caller (it fires only from the default branch)
- [ ] operator: Codex connector set to "All repositories", with Automatic review on at chatgpt.com/settings/code-review. Unblocks the cross-family first review in the new repos
- [ ] operator: `grep -c 'pr merge' ~/.config/opencode/opencode.json` should print 2 after `chezmoi apply`. If not, re-run `chezmoi apply` and answer `s` at the `.codex/config.toml` prompt
- [ ] operator: capture the live `~/.codex/config.toml` into the omarchy payload (live has `gpt-6-sol` and 3 extra trusted projects). Unblocks clean `chezmoi apply`
- [ ] operator: `rm -rf ~/Projects/workstation/omarchy-pilot-logs` once the wave PRs are merged (scratch clones and logs, no secrets)
- [ ] operator: calidad-cotizador `docker-smoke` fails on `pnpm fetch --frozen-lockfile` (pre-existing, unrelated to the suite)
- [ ] Taskwarrior `project:devops`: Fedora twin mirror; token rotation before 2027-10-04

## Verification loop
```bash
git -C ~/Projects/server/devops-pipeline ls-remote --tags origin v1 | cut -c1-7                                   # 86f1e0e (or a newer selftest-green main)
gh run list -R ZrobDev/devops-pipeline --branch main --workflow selftest --limit 1 --json conclusion -q '.[0].conclusion'   # success
doppler secrets --project fleet --config prd --only-names | grep -c 'CLAUDE_CODE_OAUTH_TOKEN'                   # 2 (token + _EXPIRES)
python3 -m json.tool ~/.claude/settings.json | grep -c 'pr merge'                                                # 2
cd ~/Projects/server/devops-pipeline && shellcheck -S warning scripts/rollout.sh && echo ok                      # ok
```

## Failure modes
| What broke | Where it hid | Root cause | Check that now forces it |
|---|---|---|---|
| Security gate green on a broken gitleaks scan | security.yml gitleaks step (old-plan YAML) | gitleaks exits 1 on both findings and its own errors; `rc -le 1` treated an error as "no report = clean" | selftest `must-fail-on-fixture` requires exit 42; `pins` job |
| Self-test green without detecting anything | selftest `!` steps | `!` inverts any non-zero, scanner errors included | `grep -c 'want 42' .github/workflows/selftest.yml` → 1 |
| Must-fail semgrep step could never fail | `.semgrepignore` listing `fixtures/` | semgrep honors ignore files even for explicit targets | AGENTS.md rule; `test ! -e .semgrepignore` |
| zizmor aborted in every caller | online `ref-confusion` audit on a private `uses:` | a caller's token cannot list the private repo's branches | selftest `templates` job runs zizmor on the callers |
| Merge deny bypassed | `Bash(gh pr merge*)` | gh accepts global flags before the subcommand | `review: does a new deny pattern cover 'gh -R x <sub>' and 'gh api'?` |
| A Claude review cancelled by any PR comment | caller workflow-level `concurrency` | skipped runs still join the group | `grep -B2 'concurrency:' templates/claude-caller.yml` shows it under `claude:` |
| Rehearse skipped a Containerfile-only PR | rehearse.yml `paths` | the filter omitted a file the script builds | `grep -c Containerfile.rehearse .github/workflows/rehearse.yml` (omarchy) → 1 |
| cp onto itself in rollout | AGENTS.md/CLAUDE.md twin copy | hard-linked twin passes `cmp` and `! -L` | `scripts/rollout.sh --repo timesheet-travel-extractor 2>&1 \| grep -c 'same file'` → 0 |
| All CI dead in payroll-pipeline | committed gitlink `.worktrees/e2e-refactor` | a worktree inside the repo was committed | `git -C <payroll> ls-tree HEAD .worktrees` → empty |

## Process lessons
- Evidence: failure rows 1 and 2. Rule: when a gate keys on a tool's exit code, run the tool once with a broken config and confirm the job FAILS; `findings` and `error` must be different codes. Scope: global-candidate.
- Evidence: omarchy #70 (Codex P1 missed by all 8 relay lanes and by altitude). Rule: keep a cross-family automatic reviewer on every PR; don't treat same-session multi-lane review as sufficient. Scope: project.
- Evidence: the wave-2 dry run caught the hard-link bug and gitleaks counts before any write. Rule: run `rollout.sh` without `--apply` over the whole tier and read every row before `--apply`. Scope: project.

## Decisions
- Kept: this repo is the single suite; callers pin `@v1`, a moving tag; third-party actions are SHA-pinned (grilling Q1, plan i-need-to-insert-vectorized-seahorse)
- Kept: Codex reviews automatically; Claude reviews on demand, owner-only and comment-only by token; no Qodo SaaS; PR-Agent documented but not deployed (Q3, Q7, Q12)
- Kept: stay on GitHub Free; checks are advisory; the human merges (Q5)
- Kept: tools from the 2026-09-04 plan (gitleaks, zizmor, semgrep CE, trivy binary, Dependabot); that plan is marked superseded
- Kept: trivy reds are fixed by Dependabot bumps, not by lowering the bar (operator, wave 2)
- Dropped: the client-facing v2 doc in ~/Downloads (operator)
- Reversed: zizmor `--offline` fallback → disable only `ref-confusion` (operator, asked)

## Memory proposals
| Action | Note | Reason |
|---|---|---|
| new | devops-pipeline-suite.md | Where the review/CI suite lives, the tiers, and that `@claude` fires only from the default branch, so a new repo needs its rollout PR merged first |
| new | rollout-gitleaks-triage.md | How hits were judged without exposing values (shape-only classification) and that fingerprints go in the rollout PR only after operator approval |

Status: pending

## Graduation candidates
- When a gate keys on an exit code, run the tool with a broken config and confirm the job fails — test: 2 projects: devops-pipeline (gitleaks rc 1 = error) and none found elsewhere; it overlaps the graduated break-the-guard rule → fails test (fold into that rule if it bites again)

## Next session
1. `/retro apply` (memory proposals pending)
2. Run the verification loop above
3. `gh pr list --author @me --state open --search "ci(security): add devops-pipeline"`: confirm merges, then re-run `scripts/rollout.sh` (dry) to confirm every row reads `nothing to add` or `exists`
4. Watch the first Dependabot PRs; on a trivy-red repo, `/ci-triage`
