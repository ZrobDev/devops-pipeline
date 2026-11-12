# Deploy over Tailscale SSH

`deploy-tailscale-ssh.yml` runs one command on a tailnet host from a GitHub
runner. Nothing secret is stored in GitHub: the runner proves who it is with
its own OIDC token, Tailscale turns that into an ephemeral `tag:ci` node,
Tailscale SSH on the host trusts the node, and sudoers on the host decides the
single command that identity may run.

```
GitHub job (environment: production)
  └─ OIDC token  sub=repo:OWNER/REPO:environment:production
       └─ Tailscale OAuth client (OIDC federated identity, scope auth_keys, tag:ci)
            └─ ephemeral node tag:ci  ──ssh──►  host, user `deploy`  (policy `ssh` rule)
                                                  └─ sudo -n -u hermes /srv/projects/REPO/vps/deploy-from-ci.sh  (sudoers)
```

## What the Free plan does and does not give you

- Private repo: environments exist and hold variables, but **no protection
  rules** (required reviewers, wait timer, branch filter). Any workflow on any
  branch can write `environment: production` and get a token with that `sub`.
  So the deploy caller triggers on `workflow_dispatch` only: the human click
  is the approval, and the `environment:` line is there for the OIDC `sub` and
  for the deployments log, not for protection. Verified 2026-11-12: the API
  returns 422 "billing plan does not support the required reviewers rule".
- Public repo, or GitHub Pro: add required reviewers and a `push: main`
  trigger; everything else stays the same.
- Actions minutes are one shared budget (2,000/month private). One deploy run
  costs about two minutes (gate + join + ssh).

## One-time setup

### 1. tailnet-policy (reviewed PR, applied by CI)

```hujson
"tagOwners": { "tag:ci": ["autogroup:admin"] },
"grants": [ { "src": ["tag:ci"], "dst": ["100.71.204.51"], "ip": ["tcp:22"] } ],
"ssh": [ { "action": "accept", "src": ["tag:ci"], "dst": ["100.71.204.51"], "users": ["deploy"] } ]
```

Use the node's MagicDNS name instead of the IP if you prefer; keep the rule to
one host and one Unix user.

### 2. Tailscale OAuth client (admin console → Settings → OAuth clients)

Type **OIDC federated identity**. Issuer `https://token.actions.githubusercontent.com`.
Subject `repo:ZrobDev/REPO:environment:production` (exact; one client per repo).
Audience: pick a fixed string, e.g. `tailscale-ci-REPO`. Scope `auth_keys`
(devices: write), tag `tag:ci`. Record the client id and the audience; neither
is a secret. Set them as **repository variables** (`gh variable set
TS_OAUTH_CLIENT_ID`, `gh variable set TS_OIDC_AUDIENCE`).

Fallback, only if federated identity is unavailable: a classic OAuth client
with a secret, stored with `gh secret set --env production TS_OAUTH_SECRET <file`
(from stdin, never argv), and `oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}`
added to the caller. Then there is a secret to rotate; the federated route has none.

### 3. The host

```sh
sudo tailscale set --ssh                                   # Tailscale SSH on this node
sudo adduser --disabled-password --gecos '' deploy          # the identity CI becomes
sudo install -m 0440 -o root -g root /dev/stdin /etc/sudoers.d/deploy-ci <<'S'
deploy ALL=(hermes) NOPASSWD: /srv/projects/REPO/vps/deploy-from-ci.sh
S
sudo visudo -c
```

`deploy` owns nothing, has no shell history worth reading and can run exactly
one path as `hermes`. The script itself lives in the deployed repo so it is
reviewed like any other change:

```sh
#!/usr/bin/env bash
set -euo pipefail
cd /srv/projects/REPO
git fetch origin main
if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then echo up-to-date; exit 0; fi
git merge --ff-only origin/main
./apply-vps.sh "$@"
```

`--ff-only` is the guard: a local edit on the host stops the deploy instead of
being merged over. Clean it up by hand, then re-run.

### 4. The caller

Copy `templates/deploy-caller.yml` into the repo's `.github/workflows/deploy.yml`,
replace `REPO`, keep `workflow_dispatch` as the only trigger on private repos.

## First run and checks

1. From a tailnet laptop allowed by a temporary `ssh` rule:
   `ssh deploy@100.71.204.51 sudo -n -u hermes /srv/projects/REPO/vps/deploy-from-ci.sh --dry-run`
   must print the dry-run steps and exit 0 with no prompt. Remove the laptop rule.
2. `gh workflow run deploy.yml` → watch the run. The `tag:ci` node appears in the
   admin console during the run and is gone after it (ephemeral).
3. `ssh ... git -C /srv/projects/REPO rev-parse HEAD` equals `git rev-parse origin/main`.
4. A second dispatch prints `up-to-date` and restarts nothing.
5. Negative check: `ssh deploy@100.71.204.51 sudo -n -u hermes bash` is refused.

## When it is red

| Symptom | Cause | Fix |
|---|---|---|
| `tailscale up` fails with an auth error | OAuth client subject does not match `repo:…:environment:production`, or the job lacks `id-token: write` | Compare the client's subject with the job's `environment:`; check `permissions` on both caller job and reusable job |
| ping succeeds, ssh is refused | no `ssh` rule for `tag:ci → host` as that user, or Tailscale SSH not enabled on the node | `tailscale set --ssh` on the host; check the policy `ssh` block |
| `sudo: a password is required` | sudoers path differs from the command | the path in sudoers and in the caller must be byte-identical |
| `fatal: Not possible to fast-forward` | local edits on the host checkout | inspect `git status` as hermes, clean, re-run |
