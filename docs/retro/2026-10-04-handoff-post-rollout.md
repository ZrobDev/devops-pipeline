# Handoff: post-rollout close-out

- Date: 2026-10-04
- Repo: ZrobDev/devops-pipeline · Branch: main
- Previous: [2026-10-04-suite-rollout.md](2026-10-04-suite-rollout.md). Read it first. It has State, Deviations, Owed, the Verification loop and the Memory proposals, none of which is repeated here.
- Design and daily use: `docs/decisions.md`, `docs/runbook.md`

## Focus of the next session

Finish the rollout close-out:
- the OpenCode merge deny live
- the rollout PRs merged and verified
- `/retro apply`

## State since the suite-rollout retro

- devops-pipeline #3 (dogfood) and #4 (rollout row fix): **merged**.
- omarchy-workstation-setup #72 (rehearse path filter adds `Containerfile.rehearse`): **merged**.
- **The live OpenCode merge deny is NOT applied.**
  - `grep -c 'pr merge' ~/.config/opencode/opencode.json` prints `0`.
  - The payload has the deny: `home/dot_config/opencode/opencode.json` gives 2 matches.
  - `chezmoi diff ~/.config/opencode/opencode.json` shows the whole `permission` block pending.
  - Most likely `chezmoi apply` stopped at the `.codex/config.toml` overwrite prompt before it reached this file.
- The omarchy local `main` is one merge behind `origin/main`: local 7fb2222, origin 21eef2a (#72).
- devops-pipeline has uncommitted `docs/retro/` (both retros plus the index) and a one-line `AGENTS.md` pointer. `origin/main` also changed `AGENTS.md`: PR #3 appended Code Review Rules. So `git merge --ff-only` may refuse until the local edit is committed or stashed.

## First actions, in order

1. Apply only the OpenCode file, so the Codex prompt can't block it:
   ```bash
   chezmoi apply ~/.config/opencode/opencode.json
   grep -c 'pr merge' ~/.config/opencode/opencode.json   # 2
   ```
2. Sync omarchy. Leave the uncommitted `lessons.md` edit alone; it belongs to the operator:
   ```bash
   git -C ~/Projects/workstation/omarchy-workstation-setup fetch origin
   git -C ~/Projects/workstation/omarchy-workstation-setup merge --ff-only origin/main
   ```
3. devops-pipeline: the operator commits `docs/retro/` and the `AGENTS.md` pointer on a branch, then opens a PR (`finish-feature`). After that merges, run `git fetch origin && git merge --ff-only origin/main`.
4. Run the Verification loop in the suite-rollout retro.
5. `/retro apply`: two memory proposals are pending there.
6. Rollout PRs:
   ```bash
   gh search prs --owner ZrobDev --state open "ci(security): add devops-pipeline"
   ```
   When none is left open, run `scripts/rollout.sh` (dry run). Every row should read `nothing to add` or `exists: …`.
7. As Dependabot bump PRs arrive on the trivy-red repos, triage them with `/ci-triage`.

## Open items not in the retro

- **payroll-pipeline #20** has 4 semgrep `use-defused-xml` findings. Its checkout works now, and its own tests, gitleaks and zizmor are green.
  - One is in owned code: `src/payroll_pipeline/infrastructure/db/build_staging_from_raw.py:16`, in a repo that stores SSNs. **This needs the operator's decision:** switch to `defusedxml`, or add a `# nosemgrep: use-defused-xml` with the reason if the XML input is trusted.
  - The other 3 are in the vendored `.agents/skills/xlsx/`.
  - trivy is red there too, on real CVEs. Per the standing decision, Dependabot fixes those.
- **Codex config drift.** The live `~/.codex/config.toml` is newer than the omarchy payload: `gpt-6-sol` instead of `gpt-5.6-sol`, plus 3 extra trusted projects. Capture the live copy into the payload. Until then, answer `s` (skip) at that chezmoi prompt.

## Guardrails for the next agent

- Never merge a PR. The merge deny is a guardrail, not a boundary; only the human merges.
- Never `git add -A`. Commit one file at a time, with Conventional Commits and a scope.
- `--no-verify` only after the operator explicitly confirms a gate.yaml hold.
- Secret values travel only through a pipe, `doppler secrets get … --plain | gh secret set …`. Never print one, and never put one in argv.
- Before the first write to any repo, run `git log --oneline -3 origin/main` and `git branch --show-current`.

## Suggested skills

| Skill | When |
|---|---|
| `retro` | `/retro apply` at session start (pending memory proposals) |
| `qmd-memory` | `qmd search "devops-pipeline"` at session start |
| `taskwarrior` | `project:devops`: Fedora twin mirror, token rotation before 2027-10-04 |
| `loop-constraints` | Right after the next plan is approved |
| `/ci-triage` or `superpowers:systematic-debugging` | Red rollout or Dependabot PRs |
| `delegate-security` | If the payroll XML finding needs a real assessment |
| `finish-feature` | Shipping the retro/handoff commit as a PR |
