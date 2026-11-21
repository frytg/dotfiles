# `.pi/`

Personal configuration and local extensions for [pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent). [`bin/link.sh`](../bin/link.sh) (run via `just link` or `just install`) symlinks `.pi/` itself to `~/.pi`, so pi reads [`agent/`](./agent) from `~/.pi/agent/`. Edit files here, not through `~/.pi/`, and run `/reload` inside pi after changes.

## Setup and updates

```sh
just install    # full bootstrap: brew, symlinks, tool upgrades, and env decrypt
just update-pi  # update pi and installed packages
```

Use `pi list` to inspect installed packages and `pi config` to enable or disable package resources.

## Auto-loaded env

The local [`load-env`](./agent/extensions/load-env/index.ts) extension reads `~/.pi/.env.personal` into `process.env` at startup before MCP servers connect, so [`mcp.json`](./agent/mcp.json) interpolations like `${GITHUB_PAT}` resolve and shell tools inherit them. Precedence: shell-exported variables win, and a missing file is a silent no-op.

`just run` (and `just install`) decrypts [`.env.personal.sops.yaml`](./.env.personal.sops.yaml) to `.pi/.env.personal` via `just decrypt-env .pi/.env.personal.sops.yaml`. Never commit the decrypted `.env.personal` file (gitignored).

## Local extensions and links

- [`optimized-footer`](./agent/extensions/optimized-footer/README.md) — replaces the default footer with git forge, MCP readiness, token/cost totals, and context bar; toggle with `/opt-footer`.
- [`agent/mcp.json`](./agent/mcp.json) — symlink to [`.agents/mcp.json`](../.agents/mcp.json). See [`docs/MCP.md`](../docs/MCP.md) before editing MCP servers.
- [`agent/AGENTS.md`](./agent/AGENTS.md) — symlink to [`.agents/AGENTS.md`](../.agents/AGENTS.md). If broken, restore with `ln -sf ../../.agents/AGENTS.md .pi/agent/AGENTS.md`.
- Skills load from `~/.agents/skills`, which `bin/link.sh` symlinks to [`skills/`](../skills).
