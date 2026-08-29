# install NixOS
[group('SYSTEM')]
install-nix:
	# see https://nixos.org/download/
	sh <(curl -L https://nixos.org/nix/install)

# install PI.dev
[group('PI')]
install-pi:
	bun add -g --ignore-scripts @earendil-works/pi-coding-agent

# install deno via mise. pins the resolved version into ~/.config/mise/config.toml
# (which link.sh symlinks to mise/config.toml in this repo — committed).
[group('SYSTEM')]
install-deno:
	#!/usr/bin/env zsh
	set -e
	if ! command -v mise >/dev/null 2>&1; then
		echo 'error: mise not on PATH' >&2
		exit 1
	fi
	mise use --global deno@latest
	mise install deno@latest
	mise reshim

# install cursor agent cli
[group('CURSOR')]
install-cursor:
	curl -fsS https://cursor.com/install | bash

# install Vercel fx CLI
[group('AI')]
install-fx:
	curl -fsSL https://fx.sh/setup.sh | bash
