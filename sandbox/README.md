# sandbox/

ephemeral sandbox setup. provisioned into fresh sandboxes via `just nsc-start NAME` (or `just nsc-provision NAME` against an existing instance).

## files

- `provision.sh` — idempotent bootstrap. installs system packages + mise + just + bun + deno + pi + fx, clones the dotfiles, runs `link-server.sh`, applies the rc files below. entry point for both Daytona and Namespace.
- `profile` — POSIX login config. written to `/etc/profile.d/zz-dotfiles.sh` so every login shell (interactive or not) inherits mise shims + bun bin on PATH.
- `zshrc` — sandbox-tuned zsh config. symlinked to `~/.zshrc` on the sandbox.
- `bashrc` — sandbox-tuned bash config. symlinked to `~/.bashrc` on the sandbox.

## workflow

```
just nsc-start mybox      # spawn + provision in one step
just nsc-shell mybox      # ssh in (PATH includes mise shims + bun bin)
just nsc-down mybox       # tear down
```

## editing

changes to any file in this folder take effect on the next `just nsc-provision NAME` against an existing sandbox — the script `git pull`s the latest dotfiles and re-applies the rc files.

## related

- `just/sandbox.just` — recipes (`nsc-up`, `nsc-shell`, `nsc-provision`, `nsc-down`, `daytona-*` parallels). imports this folder's `provision.sh` over `bash -s`.
- `bin/link-server.sh` — server-only symlinks (herdr, justfile, agents skills, .pi), invoked by `just link-server` from `provision.sh`.
- `bin/link.sh` — macOS full symlinks. not used in sandboxes (it touches Cursor/VSCode/Zed/k9s paths that don't exist on Linux).
- the host-side `.zshrc` (linked via `bin/link.sh`) is the right place for `sb-up`/`sb-down`/etc. aliases — those manage sandboxes FROM the host, not from inside one.
