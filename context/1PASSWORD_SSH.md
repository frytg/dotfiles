# 1Password SSH

SSH uses the agent on `SSH_AUTH_SOCK`. `just ssh-add-key` fills that agent with **Agent SSH Key** from the 1Password vault **Agentic**, using the service account token. The 1Password desktop agent socket is no longer in the path.

## Why the socket was the wrong hop

`.sshconfig` used to set `IdentityAgent` on `Host *` to the 1Password app socket:

```
~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

`IdentityAgent` overrides `SSH_AUTH_SOCK`. `ssh` talked to the 1Password app, while herdr sessions already pointed `SSH_AUTH_SOCK` at `~/.config/herdr/herdr.sock.agent` (a symlink to the macOS launchd agent). That agent was empty, so a key loaded into a private socket never showed up in herdr.

`.sshconfig` no longer sets `IdentityAgent`. Putting that line back sends `ssh` to the app socket and ignores the key this flow loads.

## How a shell gets the key

1. `.zshrc` reads `~/.config/1Password/herdr.token` into `OP_SERVICE_ACCOUNT_TOKEN` and unsets `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`, so `op` uses the service account. The token file stays out of the repo.
2. Herdr (or launchd) exports a live `SSH_AUTH_SOCK`. If neither did, `.zshrc` falls back to `~/.ssh/agent-herdr.sock`.
3. `just ssh-add-key` reads the item and pipes the private key to `ssh-add`. The private key is not written to disk. The public key is written to `~/.ssh/agent.pub`.

Secret references:

```text
op://Agentic/Agent SSH Key/public key
op://Agentic/Agent SSH Key/private key?ssh-format=openssh
```

The recipe keeps the current agent when `ssh-add -l` can reach it (exit 0 with keys, or exit 1 empty). Exit 2, or a missing socket, starts `ssh-agent -a ~/.ssh/agent-herdr.sock`. On this Mac the herdr socket is already live, so the key lands in the launchd agent and every herdr pane sees it.

Default lifetime is 8 hours. Run it again after a reboot or when the key expires. `just ssh-add-key 4h` sets a different lifetime.

```bash
just ssh-add-key    # load Agent SSH Key
just ssh-keys       # fingerprints currently registered
```

`op` has to be on `PATH`. A missing token file fails the recipe before it touches the agent.

## Git signing

`.gitconfig` signs commits with SSH (`gpg.format = ssh`) and `gpg.ssh.program = ssh-keygen`. `user.signingkey` is the public half of **Agent SSH Key**. `ssh-keygen` asks `SSH_AUTH_SOCK` to sign, so a commit works only while `just ssh-add-key` has registered that key. The old signer was 1Password's `op-ssh-sign`, which talks to the app and does not see this agent.

## Desktop agent config

`1password/ssh/agent.toml` is still the 1Password app's agent config. `bin/link.sh` symlinks it to `~/.config/1Password/ssh/agent.toml`. It offers the **Agentic** vault, then **Personal**. That file configures the app socket. It does not load the service-account key, and `ssh` does not consult it.
