# MCP

Pi uses `.agents/mcp.json`. Claude Code uses Anthropic's official GitHub plugin instead of syncing that
file. Cursor, Droid, and Devin each have their own MCP config because their formats differ.

## Config Locations

- **pi**
  - Reads: `~/.pi/agent/mcp.json`
  - Source: [`.agents/mcp.json`](../.agents/mcp.json), through a relative symlink at `.pi/agent/mcp.json`. `~/.pi` links to `.pi/` in this repo.
- **Claude Code**
  - Uses the [GitHub plugin](https://claude.com/marketplace/plugins/github) from Anthropic's official
    marketplace. Install it with `/plugin install github@claude-plugins-official` and choose user scope.
  - Plugin settings and installed files are managed by Claude Code, not this repo.
- **Cursor**
  - Reads: `~/.cursor/mcp.json`
  - Source: [`.cursor/mcp.json`](../.cursor/mcp.json), linked by `bin/link.sh` and edited by hand.
- **Droid**
  - Reads: `~/.factory/mcp.json`
  - Source: [`factory/mcp.json`](../factory/mcp.json), linked by `bin/link.sh`. It uses Droid's native schema, with `enabledTools` in place of Pi's `directTools`.
- **Devin**
  - Reads: `~/.config/devin/mcp_config.json`
  - Source: [`devin/mcp.json`](../devin/mcp.json), linked by `bin/link.sh`. It uses Devin's native schema (`url`/`transport`/`headers`) and has no tool allowlist, so every server exposes all its tools.

## Changing a server

1. **Edit each config:** update `.agents/mcp.json` for pi, `.cursor/mcp.json` with `${env:VAR}`,
   `factory/mcp.json` in Droid's native format, and `devin/mcp.json` in Devin's native format.
2. **Claude Code:** install or manage the GitHub plugin with `/plugin`. `just mcp` removes legacy
   user-scope MCP entries named `exa`, `firecrawl`, and `github`; it does not sync `.agents/mcp.json`
   to Claude Code. `just run` also runs this cleanup.
3. **Reload:** use `/reload` in pi, start a new Claude Code session, restart Cursor, and use `/mcp` in Droid or Devin if needed.

## Secrets

`GITHUB_PAT` is a placeholder in the MCP configs. Pi loads it from `~/.pi/.env.personal` before
connecting. Claude Code's GitHub plugin instead expects `GITHUB_PERSONAL_ACCESS_TOKEN` in the
environment that launches Claude Code. It does not read Pi's env file or the repo's `GITHUB_PAT`
setting, so the plugin cannot authenticate without that variable. Do not store the token in tracked
files.

Cursor, Droid, and Devin only see the environment they start in. A missing `GITHUB_PAT` makes their
GitHub MCP server fail to connect. Cursor or Droid started from the Dock may not see shell exports.

`victorialogs` is the self-hosted Victoria Logs MCP server on locally0. It has no auth and is only
reachable on the tailnet, so it fails to connect when Tailscale is down.

For OAuth-backed servers, log in once per tool in each client: `/mcp` in Claude Code and Droid, or the
MCP settings in Cursor.

## Figma

Figma isn't in any of the configs yet. To add it, follow the [Guide to the Figma MCP server](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server), then apply the steps in [Changing a server](#changing-a-server).

## Docs

- **pi:** [MCP Servers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/mcp.md)
- **Claude Code:** [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp)
- **Cursor:** [Model Context Protocol (MCP)](https://cursor.com/docs/mcp)
- **Droid:** [Model Context Protocol (MCP)](https://docs.factory.com/harness/mcp.md)
- **Devin:** [MCP configuration](https://docs.devin.ai/cli/extensibility/mcp/configuration) (ships with the CLI under `share/devin/docs/`)
