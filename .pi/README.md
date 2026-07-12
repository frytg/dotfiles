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

## Plugins

## Datadog

Using Datadog [Pi Plugin](https://github.com/datadog-labs/pi-plugin) instead of pure MCP server.

Setup by running `/datadog setup eu` in pi.

### Web search

Tavily is the recommended web search and content extraction provider. Install the [pi extension](https://docs.tavily.com/documentation/integrations/pi#step-3-install-the-tavily-pi-extension) and grab an API key from the [Tavily dashboard](https://app.tavily.com/home).

### Tidy Tools

Reducing output clutter using [Tidy Tools](https://github.com/mikeyobrien/pi-tidy-tools/tree/main/packages/pi-tidy-tools).
