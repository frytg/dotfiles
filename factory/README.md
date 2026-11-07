# Droid configuration

This directory holds shared Droid settings, MCP servers, and the statusline. Run
`just link` to link them into Droid's home directory. Keep that home directory local
because it also stores authentication, sessions, and machine-specific state.

## Files

- [`settings.json`](./settings.json) contains shared Droid preferences.
- [`mcp.json`](./mcp.json) defines MCP servers in Droid's config format. See the
  [MCP guide](../context/MCP.md) before changing server definitions.
- [`statusline.sh`](./statusline.sh) renders the one-line status and requires `jq`.
