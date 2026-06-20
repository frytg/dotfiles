# Agent guidance

This repository is **personal dotfiles**: shell config, editor settings, Homebrew automation, and small scripts. Treat changes as **machine-wide** once synced—prefer small, reviewable diffs and match existing style.

## Quick orientation

| Area             | Where to look                                                                                 |
| ---------------- | --------------------------------------------------------------------------------------------- |
| Symlink install  | `install.sh` — creates links from this repo into `~` and app config paths                     |
| Task runner      | `justfile` — `just` / `just --list`; common flows: `just install`, `just update`, `just brew` |
| Homebrew bundles | `brew.sh`                                                                                     |
| Backups / age    | `BACKUPS.md`, encryption-related `just` recipes in `justfile`                                 |
| Docs             | `README.md`, `LICENSE` (Unlicense)                                                            |

Editing `.vscode/settings.json` or `.zed/settings.json` affects **Cursor, VS Code, and Zed** via symlinks from `install.sh` (paths are macOS-oriented).

## Editing conventions

- **JSON / JSONC** (e.g. `biome.json`, editor settings): tabs for indentation where the file already uses tabs; keep keys and structure consistent with siblings.
- **Markdown**: `.editorconfig` uses 2-space indent for `*.md`.
- **Shell**: `install.sh` and `brew.sh` use `zsh`; preserve `set -e` / existing patterns.
- **Format/lint**: Run Biome when touching JS/TS/JSON/CSS it covers (`biome.json`). Formatter: tabs, line width 120, single quotes and `semicolons: asNeeded` for JS.

## Secrets and safety

- **Do not** add or commit secrets: private keys, `.env`, tokens, or PEM material. `.gitignore` includes `.env`, `keys/*`, `.age*.txt`, etc.
- If the user pastes sensitive values into chat, do not persist them into tracked files unless they explicitly ask and understand the risk.
- Prefer documenting _how_ to create keys (see `BACKUPS.md`) over embedding real key material.

## Git and PRs

- **Do not create commits or push** unless the user explicitly asks. If they ask for a commit, follow their stated message style and never modify `git config` or use destructive git operations without explicit request.
- This repo may be cloned on multiple hosts; avoid host-specific assumptions unless the change is clearly scoped (comments, opt-in scripts).

## Scope

- Change only what the task requires; avoid drive-by refactors across unrelated dotfiles.
- When adding new dotfiles, wire them through `install.sh` (or document manual steps in `README.md`) so the setup story stays accurate.
