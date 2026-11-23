# Cua

Cua Driver lets an agent operate native macOS apps. This repo installs it and wires its MCP server into ai agents.
Agents must ask before they use it, because it acts on your real desktop (see [Computer use](../.agents/AGENTS.md#computer-use)).

## Cua and Cua Driver

These are two separate tools from [cua.ai](https://cua.ai):

- **Cua Driver** (`cua-driver`) automates the GUI of apps on the host. It reads each window's accessibility tree and acts
  on elements, so it can click, type, and use menus in the background. It has no shell.
- **Cua Spaces** (`cua`) manages isolated sandboxes, local or in your own cloud account. An agent runs commands, moves
  files, and drives a desktop inside the Space, not on your Mac. This repo doesn't install or configure it.

## Install

1. **Install:** `just install-cua-driver` (alias `install-cua`) runs the upstream installer. It puts the app at
   `/Applications/CuaDriver.app` and links the CLI to `~/.local/bin/cua-driver`.
2. **Grant permissions:** `cua-driver permissions grant` walks through Accessibility and Screen Recording in System
   Settings. `cua-driver permissions status` checks them without asking for anything.
3. **Check:** `cua-driver doctor` reports problems. `cua-driver check-update` looks for a newer release, and
   `cua-driver update --apply` installs it.

## MCP config

The server runs as `cua-driver mcp` over stdio. Follow [`docs/MCP.md`](./MCP.md) for the general steps.

- **Droid:** the entry is in [`factory/mcp.json`](../factory/mcp.json). Droid expands `${VAR}` only in `env`, not in
  `command`, so the binary path is absolute. Change it on a host with a different home directory.
- **Claude Code:** the entry lives in `~/.claude.json`, which this repo doesn't track. Add it once per machine:

  ```sh
  claude mcp add -s user cua-driver -- ~/.local/bin/cua-driver mcp
  ```

- **pi, Cursor, Devin:** not configured.

## Troubleshooting

`ENOENT ... /Applications/Cua Spaces.app/...` means an MCP entry still points at the old Cua Spaces helper. Remove it
with `claude mcp remove -s user cua-driver` and add it again with the command above. Then reconnect with `/mcp`.

## Docs

- [Cua Driver docs](https://cua.ai/docs/cua-driver)
- Agent skill: [`skills/cua-driver/SKILL.md`](../skills/cua-driver/SKILL.md)
