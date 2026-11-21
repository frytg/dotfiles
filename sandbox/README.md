# `sandbox/`

Ephemeral Linux sandbox setup provisioned via [Namespace](https://namespace.so) (`nsc`) recipes in [`just/sandbox.just`](../just/sandbox.just).

## Files

- [`provision.sh`](./provision.sh) — idempotent bootstrap piped to `bash -s` on the instance. Installs `zsh`, `git`, `curl`, `mise`, `just`, `bun`, `pi`, and `fx`, clones the dotfiles repo, runs `just link-server`, sets `zsh` as the login shell, and applies the rc files below.
- [`profile`](./profile) — installed to `/etc/profile.d/zz-dotfiles.sh` so login shells inherit `mise` shims and `~/.bun/bin` on `PATH`.
- [`zshrc`](./zshrc) and [`bashrc`](./bashrc) — symlinked to `~/.zshrc` and `~/.bashrc` inside the sandbox.

## Workflow

```bash
just nsc-start mybox      # spawn and provision in one step
just nsc-shell mybox      # open an interactive SSH shell (forwards SSH agent)
just nsc-down mybox       # destroy the instance and remove its cached ID
```

Run `just nsc-provision mybox` to pull the latest dotfiles and re-apply rc files on a running sandbox. `nsc ssh` requires the instance UUID rather than `--unique_tag`, so `nsc-up` records the UUID in `~/.cache/nsc/<name>.id` and all `nsc-*` recipes read from there.

Override defaults via environment variables:

- OPTIONAL `DOTFILES_REPO` — clone source, defaults to `https://tangled.org/frytg.digital/dotfiles`.
- OPTIONAL `SANDBOX_MACHINE` — Namespace machine spec, defaults to `linux/amd64:2x8`.
- OPTIONAL `SANDBOX_DURATION` — instance TTL before auto-destruction, defaults to `60m`.

## Related

- [`bin/link-server.sh`](../bin/link-server.sh) — Linux/server-only symlinks (`justfile`, `skills`, `.pi`) run by `just link-server`. Do not run [`bin/link.sh`](../bin/link.sh) in sandboxes; it targets macOS paths and `ln -sfh`.
- Host-side sandbox helper aliases belong in the host [`.zshrc`](../.zshrc), not inside `sandbox/`.
