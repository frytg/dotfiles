# Droid configuration

Shared [Droid](https://docs.factory.com/droid-cli/settings) settings, MCP servers, and the one-line status script. Run `just link` ([`bin/link.sh`](../bin/link.sh)) to symlink them and [`.agents/AGENTS.md`](../.agents/AGENTS.md) into `~/.factory/`. Skills load from the shared `~/.agents/skills` symlink, and slash commands from [`commands/`](../docs/COMMANDS.md) via `~/.factory/commands`.

Before the first `just link` on an existing Droid setup, move `~/.factory/settings.json` to `~/.factory/settings.local.json` (or merge any keys you want to keep if the local file already exists). Local settings override the shared file for machine-specific values such as trusted-folder paths. Keep credentials out of [`settings.json`](./settings.json), and keep `~/.factory/` itself local because it also holds auth, sessions, and caches.

## Files

- [`settings.json`](./settings.json) — shared Droid preferences.
- [`mcp.json`](./mcp.json) — MCP servers in Droid's native schema (`enabledTools` instead of Pi's `directTools`). Read [`docs/MCP.md`](../docs/MCP.md) before changing servers.
- [`statusline.sh`](./statusline.sh) — renders model, directory, Git branch or detached commit, and context percentage; requires `jq` and hides context until Droid provides usage. Validate changes with `droid statusline-probe`.
