# Agent guidance

This repository is **personal dotfiles**: shell config, editor settings, Homebrew automation, and small scripts. Treat changes as **machine-wide** once synced.

For cross-cutting rules (code style, secrets, commits, etc.) see [`.agents/AGENTS.md`](./.agents/AGENTS.md).

## Symlink workflow

- New dotfiles are wired through `link.sh` (or have manual steps documented in `README.md`).
- Editor settings are shared: `.vscode/settings.json` is symlinked to Cursor and VS Code, `.zed/settings.json` to Zed.

## Skills

- New skills live in `skills/<category>/<name>/SKILL.md` in this repo, where `<category>` is one of the existing top-level folders (`engineering`, `productivity`, `writing`, `media`, `social`, `ard`, `osaurus-browser`); create a new category only when none fits.
- Each skill is a single `SKILL.md` with YAML frontmatter (`name`, `description`) and a Markdown body, per the [Agent Skills spec](https://agentskills.io/specification.md). Portability rules and the synthetic-example rule (no real names, IDs, internal hosts) live in [`.agents/AGENTS.md`](./.agents/AGENTS.md) and override anything below.
- `bin/link.sh` wires `skills/` into pi, cursor, fx, and osaurus. Run `just link` after adding or moving a skill so the harness picks it up. See [`skills/README.md`](./skills/README.md) for the harness discovery paths.
- The legacy path `~/.pi/agent/skills/` symlinks to a separate vault — don't add new skills there.

## Editing conventions

- Shell scripts use `zsh` with `set -e`; preserve existing patterns.

## Secrets and safety

- Use the `.gitignore` (`.env`, `keys/*`, `.age*.txt`). For key creation, see `docs/BACKUPS.md`.
- If the user pastes a sensitive value into chat, do not persist it to tracked files unless they explicitly ask.

## Git and PRs

- **Do not create commits or push** unless the user explicitly asks. If they do, follow their stated message style and never modify `git config` or run destructive git operations without explicit request.
- This repo is cloned on multiple hosts; avoid host-specific changes unless scoped to a comment or opt-in script.
