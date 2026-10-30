# MCP

Pi and Claude Code share one MCP config, and Cursor has its own. Pi and Claude Code both write env vars as `${VAR}`, but Cursor needs `${env:VAR}`, so one file can't serve all three.

## Where each tool reads its servers

- **pi:** reads `~/.pi/agent/mcp.json`. `~/.pi` links to `.pi/` in this repo, and `.pi/agent/mcp.json` is a relative symlink to [`.agents/mcp.json`](../.agents/mcp.json).
- **Claude Code:** reads user-scope servers from the `mcpServers` key in `~/.claude.json`. That file also holds session state, so it can't be a symlink. `just mcp` copies each server from [`.agents/mcp.json`](../.agents/mcp.json) into it with `claude mcp add-json -s user`, without the pi-only `directTools` key.
- **Cursor:** reads `~/.cursor/mcp.json`. `bin/link.sh` links it to [`.cursor/mcp.json`](../.cursor/mcp.json), which you edit by hand.

## Changing a server

1. **Edit both files:** change `.agents/mcp.json` with `${VAR}`, then make the same change in `.cursor/mcp.json` with `${env:VAR}`.
2. **Sync Claude Code:** run `just mcp`. `just run` also does this. It only adds and updates servers. To remove one, run `claude mcp remove -s user <name>`.
3. **Reload:** use `/reload` in pi, start a new Claude Code session, and restart Cursor.

## Secrets

`GITHUB_PAT` is only a placeholder in these files. Pi loads its value from `~/.pi/.env.personal` itself. Claude Code and Cursor only see the environment they start in. If the value is missing, the GitHub server fails to connect, and `claude mcp list` shows a warning. Cursor started from the Dock never sees shell exports.

The other servers use OAuth. Log in once per tool: `/mcp` in Claude Code, and the MCP settings in Cursor.
