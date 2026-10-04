# Secrets setup

One secret drives this suite: `CLAUDE_CODE_OAUTH_TOKEN`, used by the on-demand
Claude review. Doppler project `fleet`, config `prd`, is its only source of
truth; `scripts/rollout.sh` copies it into each active repo's Actions secrets.
A personal GitHub account has no account-level Actions secrets, so the copy
per repo is unavoidable. Doppler makes rotation one command instead of 30.

## Claude token

1. **Generate.** In a Claude Code session run `! claude setup-token`, finish
   the browser login, copy the printed `sk-ant-oat…` token. It lasts one year
   and draws on your Claude subscription, not an API bill.
2. **Store in Doppler.** It prompts for the value, so it stays out of shell
   history and argv:
   ```
   doppler secrets set CLAUDE_CODE_OAUTH_TOKEN --project fleet --config prd
   ```
   Record the expiry. A date is not a secret, so argv is fine here:
   ```
   doppler secrets set CLAUDE_CODE_OAUTH_TOKEN_EXPIRES=YYYY-MM-DD --project fleet --config prd
   ```
3. **Reminder.**
   ```
   task add project:devops "Rotate CLAUDE_CODE_OAUTH_TOKEN" due:<expiry minus 30 days> +security
   ```
4. **Distribute.** Dry run first. It lists every active repo and whether the secret exists:
   ```
   scripts/rollout.sh --secrets-only
   scripts/rollout.sh --secrets-only --apply
   ```
5. **Verify.** `gh secret list -R ZrobDev/<repo>` shows `CLAUDE_CODE_OAUTH_TOKEN`
   updated today. Comment `@claude review` on an open PR; a review comment
   appears within a few minutes (`gh run list -R ZrobDev/<repo> -w "Claude review"`).
6. **Rotate.** Repeat steps 1, 2 and 4. `--secrets-only` always overwrites.
7. **Revoke (leak).** Revoke the token in claude.ai settings first: that kills
   it everywhere at once. Then remove the copies:
   ```
   for r in $(gh repo list ZrobDev --limit 200 --no-archived --json name -q '.[].name'); do
     gh secret delete CLAUDE_CODE_OAUTH_TOKEN -R "ZrobDev/$r" 2>/dev/null </dev/null && echo "deleted: $r"
   done
   ```

What this does not buy: an Actions secret is readable by any workflow change
merged to that repo. The Claude workflow is owner-triggered and its job token
is read-only, but the OAuth token itself is a full credential for your Claude
subscription. Merge workflow changes only after reading them.

## Codex automatic review (no secret, manual)

1. github.com/settings/installations → **ChatGPT Codex Connector** → Configure →
   Repository access: **All repositories**.
2. chatgpt.com/settings/code-review → enable each repo → turn on **Automatic
   review**; set the trigger to PR opened / ready for review.
3. On the first Dependabot PR, check whether Codex reviewed it. If it did and it
   is eating quota, narrow the trigger.

Codex reads the `## Code Review Rules` section of `AGENTS.md`;
`rollout.sh` appends `templates/code-review-rules.md` there.

## Optional: PR-Agent

Not deployed. If it is ever turned on (see `decisions.md`), its key lives at
`doppler … fleet/prd OPENROUTER_KEY` and reaches the repo the same way: pipe
`doppler secrets get --plain` into `gh secret set`. Never put the value in argv.
