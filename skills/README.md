# Skills Documentation

This repository houses the specialized skills used by various AI harness systems.

Each AI harness reads its available skills from the following sources:

- **pi** (via the Pi coding agent harness, reads from `~/.agents/skills/`)
- **cursor** (via the Cursor AI harness, reads from `~/.cursor/skills-cursor/`)
- **osaurus** (reads from `~/.osaurus/skills/`; no symlinks, no nested category folders — `link.sh` flatten-copies each leaf skill)

For more information on how these skills are managed and linked across the environment, please see [`link.sh`](link.sh).

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
OPEN_WEBUI_URL: https://chat.example.com   # base url, no trailing slash
OPEN_WEBUI_API_KEY: sk-...                 # bearer token, admin or workspace.skills permission
```

Runtime: [bun](https://bun.sh) (handles TS natively, no build step). No third-party dependencies.
