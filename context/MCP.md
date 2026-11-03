# MCP

Pi and Claude Code share one MCP config, and Cursor has its own. Pi and Claude Code both write env vars as `${VAR}`, but Cursor needs `${env:VAR}`, so one file can't serve all three.

## Config Locations

- **pi**
  - Reads: `~/.pi/agent/mcp.json`
  - Source: [`.agents/mcp.json`](../.agents/mcp.json), through a relative symlink at `.pi/agent/mcp.json`. `~/.pi` links to `.pi/` in this repo.
- **Claude Code**
  - Reads: the `mcpServers` key in `~/.claude.json` (user scope)
  - Source: [`.agents/mcp.json`](../.agents/mcp.json), copied in by `just mcp` with `claude mcp add-json -s user`, without the pi-only `directTools` key. `~/.claude.json` also holds session state, so it can't be a symlink.
- **Cursor**
  - Reads: `~/.cursor/mcp.json`
  - Source: [`.cursor/mcp.json`](../.cursor/mcp.json), linked by `bin/link.sh` and edited by hand.

## Changing a server

1. **Edit both files:** change `.agents/mcp.json` with `${VAR}`, then make the same change in `.cursor/mcp.json` with `${env:VAR}`.
2. **Sync Claude Code:** run `just mcp`. `just run` also does this. It only adds and updates servers. To remove one, run `claude mcp remove -s user <name>`.
3. **Reload:** use `/reload` in pi, start a new Claude Code session, and restart Cursor.

## Secrets

`GITHUB_PAT` is only a placeholder in these files. Pi loads its value from `~/.pi/.env.personal` itself. Claude Code and Cursor only see the environment they start in. If the value is missing, the GitHub server fails to connect, and `claude mcp list` shows a warning. Cursor started from the Dock never sees shell exports.

`victorialogs` is the self-hosted Victoria Logs MCP server on locally0. It has no auth and is only reachable on the tailnet, so it fails to connect when Tailscale is down.

The other servers use OAuth. Log in once per tool: `/mcp` in Claude Code, and the MCP settings in Cursor.

## Docs

- **pi:** [MCP Servers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/mcp.md)
- **Claude Code:** [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp)
- **Cursor:** [Model Context Protocol (MCP)](https://cursor.com/docs/mcp)
