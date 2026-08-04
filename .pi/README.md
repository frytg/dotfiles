# `.pi/`

Personal config for [pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent), the coding agent.

## Overview

This directory holds pi's runtime config. `link.sh` symlinks the files here into `~/.pi/agent/` so pi picks them up at startup. Edit files in this directory, not in `~/.pi/agent/` — the symlink points back here, and only commits persist.

## Install

From the repo root:

```sh
just install
```

## Manage

- `pi list` — list installed packages
- `pi config` — enable or disable package resources
- `/atlas` to see token usage

## Plugins

### Optimized footer

Local directory extension: [`agent/extensions/optimized-footer/`](./agent/extensions/optimized-footer/).

- entrypoint: `index.ts` (auto-discovered as `extensions/*/index.ts`)
- docs: [`README.md`](./agent/extensions/optimized-footer/README.md) — goals, layout, MCP semantics, setup

Loads via `PI_CODING_AGENT_DIR=~/.dotfiles/.pi/agent`. Toggle with `/opt-footer`. Use `/reload` after edits.

## Datadog

Using Datadog [Pi Plugin](https://github.com/datadog-labs/pi-plugin) instead of pure MCP server.

Setup by running `/datadog setup eu` in pi.

### MCP

Setup [`pi-mcp-adapter`](https://pi.dev/packages/pi-mcp-adapter) using [mcp.json](../.agents/mcp.json).

Then run `/mcp-auth` in pi to authenticate with the MCP server.

### Web search

Using [Exa](https://dashboard.exa.ai/home) through their [MCP server](https://exa.ai/docs/reference/exa-mcp) for search and web extraction (not agents).

### Tidy Tools & Sub-Agents

Reducing output clutter using [Tidy Tools](https://github.com/mikeyobrien/pi-tidy-tools/tree/main/packages/pi-tidy-tools).

Adding sub-agents to pi using [`pi-tidy-subagents`](https://github.com/mikeyobrien/pi-tidy-tools/tree/main/packages/pi-tidy-subagents). See docs or [reference.md](https://github.com/mikeyobrien/pi-tidy-tools/blob/main/packages/pi-tidy-subagents/docs/reference.md) for setup and usage.

## Symlinking files

Some references are already symlinked. If broken, run this again:

```sh
ln -sf ../../.agents/AGENTS.md .pi/agent/AGENTS.md
```

The skills directory is linked into `~/.agents/skills`, which gets [picked up by pi](https://pi.dev/docs/latest/skills#locations).

## Trio

Setup [trio](https://github.com/jnsahaj/trio) with `/trio`, after which it can execute `planner -> executor -> reviewer` on its own with one model each.
Also see [@iamsahaj_xyz](https://x.com/iamsahaj_xyz/status/2077842986806001746).

Config gets saved to [`trio.json`](./agent/trio.json)
