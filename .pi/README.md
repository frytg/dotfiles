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
