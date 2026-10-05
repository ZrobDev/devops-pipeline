# Handoff: open items after the fleet went green

- Date: 2026-10-04 · Repo: ZrobDev/devops-pipeline · `main` @ 0acc473 (clean)
- Read first: [2026-10-04-trivy-reds-to-green.md](2026-10-04-trivy-reds-to-green.md), the full record (State, Deviations, Failure modes, Verification loop, Memory proposals). Also [NOTES.md](NOTES.md): 2 lines the next `/retro` absorbs. Nothing from either is repeated here.
- Design and daily use: `docs/decisions.md`, `docs/runbook.md`

## Where things stand

### Fleet
- All 11 active repos are green on their default branch's latest `security` run.
- astro-zrobdev-portfolio is **archived**: an untouched Cloudflare starter template; its CRITICAL fix needs astro 5→7.
- No rollout PR is open (30 closed or merged).

### Suite
- `v1` = 07c453a (`--ignore-unfixed`). Confirmed in callers' run logs.

### Repo
- devops-pipeline PRs #5–#8 are merged.
- No local branches besides `main`.

## Focus of the next session (none blocking)

1. **`/retro apply`.**
   - 3 memory proposals are pending in the trivy-reds-to-green retro.
   - Run that retro's Verification loop first; its `gh search prs` line was fixed in #8.
   - Fleet-loop rows that now differ from what the retro wrote are expected: soi, split and financial are green now, astro is archived, lease is green.
2. **Dokploy check (operator, on the host).** markit#8 and 2markit#13 made both containers run as uid 10001, with `CMD` changed to `/app/.venv/bin/fastapi`.
   ```bash
   docker exec <markit-container> id -u     # 10001
   docker exec <2markit-container> id -u    # 10001
   # plus each app's /health → 200
   ```
   If a deployed container crash-loops on `Failed to initialize cache at .cache/uv`, the deploy is still running the old `CMD`. Rebuild from `main`.
3. **payroll-pipeline #18** (happy-dom 18→20 in `frontend/`, `build-and-test` red). Run `/ci-triage`.
   - It's a major dev-dependency bump. Fix the tests on the PR branch, or close it and pin `happy-dom` to 18.x.
   - Separately, `test_check_stub_extraction_accuracy` already fails on `master`. It's unrelated to #18; don't let it confuse the triage.
   - payroll's default branch is **`master`**.
4. **Decision for the operator: Dependabot cooldown vs security fixes.**
   - `templates/dependabot.yml` sets `cooldown: { default-days: 7 }` on every ecosystem.
   - Observed: the grouped version-update PRs (soi #7, financial #5) left out the fixed anyio and urllib3 versions. The individual security PRs opened before the rollout couldn't be rebased, so targeted `uv lock --upgrade-package` PRs filled the gap.
   - Before proposing anything, verify in the current Dependabot docs whether `cooldown` applies to security updates and whether a `semver`/`include` exclusion exists. Then put the options to the operator.
   - Any template change is a devops-pipeline PR, but templates reach repos only via `rollout.sh`, which skips existing files. Existing repos would need their own edits.
5. Leftover Dependabot PRs: **soi #7** and **financial #5** (grouped routine bumps). Merge them when green, or leave them; they aren't needed for security.

## Rules for the next agent
- Never merge. The operator merges on GitHub.
- When giving the operator a cleanup sequence, guard it with `test (gh pr view <n> --json state --jq .state) = MERGED; and …`. An unguarded delete once closed a live PR (#7).
- Before any base or `origin/<branch>`: `gh repo view --json defaultBranchRef`.
- Before recommending a settings or policy change: `grep -n -i '<setting>' docs/decisions.md`.
- Stage files by name, never `git add -A`.
- Scratch dirs are tmpfs (`df -T`). Fleet-wide clones and venvs filled one; delete clones when done.
- Third-party tools come from pinned, checksum-verified binaries. trivy 0.74.0 and semgrep 1.176.1 aren't installed locally; fetch them as `security.yml` does.

## Suggested skills
| Skill | When |
|---|---|
| `retro` (`/retro apply`) | First: staleness audit plus the 3 pending memory proposals |
| `qmd-memory` | At session start: `qmd search "devops-pipeline"` |
| `superpowers:systematic-debugging` | payroll #18 happy-dom failure (no `/ci-triage` skill is installed in this listing; use this if it's absent) |
| `find-docs` / Context7 | The Dependabot `cooldown` and security-update behaviour, before the decision in item 4 |
| `finish-feature` | Any devops-pipeline change that comes out of item 4 |
| `retro` (`/retro`) | End of session |
