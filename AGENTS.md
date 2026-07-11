# Agent guidance

This repository is **personal dotfiles**: shell config, editor settings, Homebrew automation, and small scripts. Treat changes as **machine-wide** once synced.

For cross-cutting rules (code style, secrets, commits, etc.) see [`.agents/AGENTS.md`](./.agents/AGENTS.md).

## Symlink workflow

- New dotfiles are wired through `link.sh` (or have manual steps documented in `README.md`).
- Editor settings are shared: `.vscode/settings.json` is symlinked to Cursor and VS Code, `.zed/settings.json` to Zed.

## Editing conventions

- Shell scripts use `zsh` with `set -e`; preserve existing patterns.

## Secrets and safety

- Use the `.gitignore` (`.env`, `keys/*`, `.age*.txt`). For key creation, see `BACKUPS.md`.
- If the user pastes a sensitive value into chat, do not persist it to tracked files unless they explicitly ask.

## Git and PRs

- **Do not create commits or push** unless the user explicitly asks. If they do, follow their stated message style and never modify `git config` or run destructive git operations without explicit request.
- This repo is cloned on multiple hosts; avoid host-specific changes unless scoped to a comment or opt-in script.
