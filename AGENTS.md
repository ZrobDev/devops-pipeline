# devops-pipeline

The maintenance suite for every ZrobDev repo: reusable GitHub workflows
(security gates, on-demand Claude review), caller templates, the rollout
script, and the runbook. `CLAUDE.md` is a symlink to this file.

Read `docs/decisions.md` before changing what the suite does; read
`docs/runbook.md` for how it is used day to day.

## Rules

- **Never run `gh pr merge`.** Only the human merges, after checks are green.
- Third-party actions are pinned to a 40-character SHA with the version in a
  comment. Own-repo refs (`ZrobDev/devops-pipeline/...@v1`) use the moving tag.
- Tool versions and checksums in `security.yml` and `selftest.yml` move in
  lockstep. Resolve checksums from the upstream `checksums.txt`; never type one.
- `zizmor.yml` and the inline config in `security.yml` move in lockstep.
- `fixtures/` is deliberately vulnerable. selftest is green only because the
  tools FAIL on it. Do not "fix" it, and do not add an ignore file that hides it
  (a `.semgrepignore` listing `fixtures/` did exactly that once).
- `${{ }}` holding user-controlled text never appears in `run:`; pass it via `env:`.
- `claude-review.yml` stays comment-only: job token `contents: read`, fixed
  `prompt`, no Edit/Write/push tools.
- Move `v1` only after `selftest` is green on `main`: a bad `v1` breaks every repo at once.
- `scripts/rollout.sh` stays dry-run by default and never merges. Secret values
  travel by pipe only, never argv, a variable, or output.
