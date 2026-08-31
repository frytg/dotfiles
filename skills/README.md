# Skills Documentation

This repository houses the specialized skills used by various AI harness systems.

Each AI harness reads its available skills from the following sources:

- **pi** (via the Pi coding agent harness, reads from `~/.agents/skills/`)
- **cursor** (via the Cursor AI harness, reads from `~/.cursor/skills-cursor/`)
- **fx** (via the `fx` CLI, reads from `~/.fx/skills/`; no symlinks, no nested category folders — `link.sh` flatten-copies each leaf skill)
- **osaurus** (reads from `~/.osaurus/skills/`; no symlinks, no nested category folders — `link.sh` flatten-copies each leaf skill)

## Full discovery paths per harness

The list above only shows what `bin/link.sh` wires on this host. Each harness also reads from additional roots per its docs.

- **pi** ([docs/skills.md](https://github.com/earendil-works/pi-coding-agent/blob/main/docs/skills.md))
  - global: `~/.pi/agent/skills/`, `~/.agents/skills/`
  - project (trusted only): `.pi/skills/`, `.agents/skills/`
    - walked from `cwd` up to the git repo root (or filesystem root outside a repo)
  - extras:
    - `skills/` dirs or `pi.skills` entries in `package.json`
    - `skills` array in `settings.json` (files or dirs)
    - `--skill <path>` on the CLI (repeatable, additive even with `--no-skills`)
- **cursor** ([cursor.com/docs/skills](https://cursor.com/docs/skills))
  - global: `~/.agents/skills/`, `~/.cursor/skills/`
  - project: `.agents/skills/`, `.cursor/skills/`
    - recurses into nested subdirs; nested skills are auto-scoped to files inside that subdir
  - compat: `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/`
  - note: `~/.cursor/skills-cursor/` is built-in, not for user content
- **fx** ([fx.sh/docs/capabilities/skills](https://fx.sh/docs/capabilities/skills))
  - workspace (cwd → home, in precedence order):
    - `skills/`, `.opencode/skills/`, `.codex/skills/`, `.claude/skills/`, `.agents/skills/`, `.claw/skills/`
  - global (home):
    - `~/.fx/skills/` — the only path `fx install` writes
    - `~/.config/opencode/skills/`, `~/.codex/skills/`, `~/.claude/skills/`, `~/.agents/skills/`, `~/.claw/skills/`
  - note: additional workspace directories don't contribute skills
- **osaurus** ([docs.osaurus.ai/skills](https://docs.osaurus.ai/skills))
  - global: `~/.osaurus/skills/{skill-name}/SKILL.md` (flat, no nested category folders)
    - with optional `references/` and `assets/` subfolders
  - imports:
    - any GitHub repo carrying `.claude-plugin/marketplace.json`
    - full directory-based Claude plugin layout: skills + scheduled agents + slash commands + MCP providers + shared `CLAUDE.md`

For more information on how these skills are managed and linked across the environment, please see [`link.sh`](../bin/link.sh).

## Syncing to an Open WebUI instance

[`bin/sync-skills.ts`](../bin/sync-skills.ts) pushes the local `skills/<category>/<id>/SKILL.md` set to an [Open WebUI](https://docs.openwebui.com/) instance over its REST API (`/api/v1/skills/...`). Each skill's `name` and `description` come from the YAML frontmatter; the markdown body becomes `content`; the category folder becomes a `meta` tag. Existing skills are updated in place, new ones are created; pass `--prune` to delete remote skills missing locally, `--dry-run` to print the plan without making changes.

Run via the [`_env`](../justfile) recipe (which wraps `sops exec-env`) so the API URL and token come from an encrypted `.env.sops.yaml`:

```sh
# default sops file is .env.sops.yaml; override with SOPS_ENV_FILE=...
just sync-skills                    # create + update
just sync-skills --dry-run          # show planned operations
just sync-skills --prune            # also delete remote-only skills
SOPS_ENV_FILE=.pi/.env.personal.sops.yaml just sync-skills --prune
```

Required sops entries:

```yaml
OPEN_WEBUI_URL: https://chat.example.com # base url, no trailing slash
OPEN_WEBUI_API_KEY: sk-... # bearer token, admin or workspace.skills permission
```

Runtime: [bun](https://bun.sh) (handles TS natively, no build step). No third-party dependencies.
