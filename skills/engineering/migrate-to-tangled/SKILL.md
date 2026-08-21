---
name: migrate-to-tangled
description: Migrate a GitHub repository to Tangled and optionally mirror it back to GitHub via a Spindle workflow. Use when the user asks to move a repo to Tangled, mirror a GitHub repo to Tangled, set up a Tangled mirror that pushes back to GitHub, or replicate their workflow onto a federation-based git host.
license: MIT
metadata:
  author: frytg
  agent: pi
---

# Migrate to Tangled

Tangled is a federated git host built on AT Protocol. All repos are public; identity is your AT Proto handle. This skill migrates a single repo end-to-end and optionally stands up a GitHub-mirror Spindle so the old repo stays readable on GitHub until you redirect traffic.

Tangled has no public write API yet, so signup, repo creation, secrets, and deploy keys all happen in the browser. Git history copy, remote rewiring, key generation, and the Spindle workflow file itself are CLI/file work and can be automated.

Each step below is tagged **[agent]** (run via tools) or **[user]** (browser-only — walk through it). Confirm with the user before any operation that mutates remotes or pushes.

A worked example with real-world data: https://www.frytg.digital/blog/2026-07-28-migrating-to-tangled/.

## 0. Gather inputs

Get these from the user up front; everything below references them:

- **Source clone URL** on GitHub, e.g. `git@github.com:acme/example.git`. User must have push access.
- **Tangled handle**, e.g. `alice.bsky.team`. They should have signed into tangled.org at least once so the identity exists.
- **Target repo name** on Tangled, e.g. `example`. Will become `tangled.org/<handle>/<repo>` and `git@tangled.org:<handle>/<repo>.git`.
- **Default branch**. Usually `main`. Confirm with `git remote show origin | grep 'HEAD branch'` or `git symbolic-ref refs/remotes/origin/HEAD`.
- **GitHub-mirror?** If yes, the user needs push access on the _destination_ GitHub repo (often the source itself).

Tooling checks the agent should run:

```bash
command -v git-sync ssh-keygen ssh-agent git
```

If `git-sync` is missing, install it (`brew install git-sync`, or `go install github.com/simulot/git-sync@latest`). The blog post's install link is the project's authoritative source.

## 1. Tangled identity + SSH key (browser)

The OAuth sign-in and the SSH-key registration are both browser-only.

**[user]** Go to **https://tangled.org** and sign in via AT Proto OAuth (e.g. "Sign in with Bluesky" or their PDS app).

**[agent]** After sign-in, resolve the handle to a DID and stash it — it's the user's permanent identity and you'll use it throughout:

```bash
DID=$(curl -s "https://tngl.sh/xrpc/com.atproto.identity.resolveHandle?handle=<HANDLE>" | jq -r .did)
echo "$DID"
```

**[user]** Skip if a key for this machine is already on Tangled. Otherwise, have the agent generate the key (next step) and then paste the public key at **https://tangled.org/settings/keys** with a recognisable title (e.g. `work-laptop`), then save.

**[agent]** Generate the key and print the public half:

```bash
ssh-keygen -t ed25519 -C "<user email>" -f ~/.ssh/id_ed25519_tangled
cat ~/.ssh/id_ed25519_tangled.pub
```

**[agent]** Verify the connection works (no expected greeting text — just no `Permission denied (publickey)`):

```bash
ssh -T git@tangled.org
```

If that handshake fails, the public key isn't registered yet (or the wrong file was pasted). Don't proceed until it succeeds.

## 2. Create the target repository (browser)

Tangled has no API for repo creation yet, so this is browser-only.

**[user]** Go to **https://tangled.org/repo/new**, set the repo name, leave it **empty** (no README, no `.gitignore` — the migration will bring everything; creating them here causes an immediate non-fast-forward when migrating onto it).

On save, the repo page shows two equivalent clone URLs:

- Handle form: `git@tangled.org:<handle>/<repo>.git`
- DID form: `git@tangled.org:<did>/<repo>.git`

**[agent]** Capture both forms — the DID one is what `git-sync` and `git remote set-url` should use.

## 3. Migrate git history

`git-sync` is the recommended path: it copies refs from one remote to another without touching local history.

**[agent]** Run the sync into the new empty repo. This creates a temp working dir; size-dependent run time.

```bash
git-sync sync \
  --branch <DEFAULT_BRANCH> \
  "<SOURCE_GH_CLONE_URL>" \
  "<TANGLE_CLONE_URL>"
```

Look for the "Everything up-to-date" landing-page message at the end.

**Stop and confirm with the user before mutating remotes or pushing.** `git remote set-url origin` redirects where `git push origin` goes — get explicit consent.

Then rewire the user's local working copy:

```bash
cd <LOCAL_REPO>
git remote -v                                   # show current remotes
git remote set-url origin "<TANGLE_CLONE_URL>"
git push origin <DEFAULT_BRANCH>                # confirm with user before running
```

If they want both remotes active during the transition (pushes write to both):

```bash
git remote set-url --push origin    "<TANGLE_CLONE_URL>"
git remote set-url --add --push origin "<SOURCE_GH_CLONE_URL>"
git push origin <DEFAULT_BRANCH>                # confirm with user before running
```

**[agent]** Verify after the push:

```bash
git remote show origin                          # should now show Tangled as origin
ssh -T git@tangled.org                          # handshake clean
```

## 4. Optional: GitHub-mirror Spindle

Only if the user wants the GitHub repo to keep receiving commits as long as it's still online. The pattern: a Spindle on Tangled pushes to GitHub on every push to `main` using a write-enabled GitHub deploy key. Always confirm before writing files, committing, or pushing.

### 4a. Write the workflow file

Create `.tangled/workflows/github-mirror.yml`. Replace the placeholders `<owner>`, `<repo>`, `<display name>`, `<bot email>`; do not commit any secrets.

```yaml
# Mirror pushes from Tangled to GitHub
# Required secret: GITHUB_DEPLOY_KEY (private SSH key; add in repo Settings → Secrets)
when:
  - event: ['push', 'manual']
    branch: ['main']

engine: microvm
image: nixos

clone:
  depth: 10

dependencies:
  - git
  - openssh

registry:
  nixpkgs: github:nixos/nixpkgs/nixos-unstable

environment:
  GIT_REMOTE_REPO: 'git@github.com:<owner>/<repo>.git'

steps:
  - name: 'Mirror to GitHub'
    command: |
      set -euo pipefail

      if [ -z "${GITHUB_DEPLOY_KEY:-}" ]; then
        echo "GITHUB_DEPLOY_KEY not set — skipping"
        exit 0
      fi

      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      touch "$HOME/.ssh/known_hosts"

      eval "$(ssh-agent -s)" > /dev/null
      ssh-add - <<< "${GITHUB_DEPLOY_KEY}"
      ssh-keyscan -t rsa,ed25519 github.com >> "$HOME/.ssh/known_hosts"

      git config user.name "<display name>"
      git config user.email "<bot email>"
      git remote add mirror "${GIT_REMOTE_REPO}"
      git push --force mirror "HEAD:refs/heads/${TANGLED_REF_NAME:-main}"
```

Commit and push to the default branch.

### 4b. Enable the hosted Spindle (browser)

**[user]** Open the Tangled repo → **Settings → Pipelines** → choose the default hosted Spindle → save. One-time per repo.

### 4c. Generate a dedicated deploy key (agent)

GitHub deploy keys are repo-scoped and write-once per public key. Generate a fresh pair for this mirror; do not reuse the user's personal keys.

```bash
ssh-keygen -t ed25519 -C "tangled-mirror-<repo>" -f /tmp/tangled-mirror-<repo>
chmod 600 /tmp/tangled-mirror-<repo>
```

Two files matter:

- `/tmp/tangled-mirror-<repo>.pub` → goes to GitHub.
- `/tmp/tangled-mirror-<repo>` → goes to Tangled secrets as `GITHUB_DEPLOY_KEY`.

### 4d. Register the secret on Tangled (browser)

**[user]** Tangled repo → **Settings → Secrets** → add secret `GITHUB_DEPLOY_KEY`, paste the **entire** private key contents (including `-----BEGIN OPENSSH PRIVATE KEY-----` and the matching footer), save. No quoting or trimming.

### 4e. Register the deploy key on GitHub (browser)

**[user]** GitHub repo → **Settings → Deploy keys → Add deploy key**. Title `tangled-mirror-<repo>`, paste the public-key file, **toggle "Allow write access" ON**, add the key.

### 4f. First run

**[user]** From the Tangled repo's Pipelines tab, trigger `github-mirror` manually. Watch the logs for these checkpoints:

- `GITHUB_DEPLOY_KEY not set — skipping` → secret wasn't pasted correctly.
- `Permission denied (publickey)` → wrong public key on GitHub, or `ssh-keyscan` didn't pre-load the host.
- `repository not found` → wrong `GIT_REMOTE_REPO`, or the user lacks write access on the GitHub side.

**[agent]** After the run succeeds, verify on GitHub: the SHA shown in the workflow log matches the tip of the GitHub repo's default branch.

## 5. Cleanup

**[agent]** After a successful first mirror:

```bash
shred -u /tmp/tangled-mirror-<repo> /tmp/tangled-mirror-<repo>.pub
```

`shred` is best-effort on flash storage. The private key lived on disk in plaintext; do not reuse either file. If the user wants extra peace of mind, rotate the key (regenerate, re-paste on both sides, re-test).

Optional follow-ups to raise with the user:

- Pin the repo on Tangled, add a description, topics (via the repo `…` menu).
- Update the GitHub repo's README/About to point readers at the new canonical home.
- Redirect any package registries (npm, crates.io, etc.) that pointed at the GitHub URL.
- If the user wants to fully abandon GitHub, archive (don't delete) the repo so old links keep resolving.

## When **not** to use this skill

- The user wants to _read_ from an existing Tangled repo — reach for the `tangled` skill instead.
- The user wants a mirror in the opposite direction (GitHub Actions triggered on Tangled push) — that's GitHub-side, not Spindles; not covered here.
- The source repo is private. Tangled has no private repos yet; migration makes the code public. Surface this risk explicitly and let the user decide.

## Safety notes

- Confirm with the user before any `git remote set-url`, `git push`, or commit; the global agent rule is "never push on your own."
- The private deploy key exists on local disk briefly. Don't sync it into a backup, dotfiles repo, or anywhere that would retain it.
- Tangled's web UI labels move; if "Settings → Pipelines" or "Settings → Secrets" looks different, look for the same conceptual mapping (pipelines enable the runner, secrets store per-repo values).
