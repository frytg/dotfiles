# install NixOS
[group('INSTALL')]
install-nix:
	# see https://nixos.org/download/
	sh <(curl -L https://nixos.org/nix/install)

# install PI.dev
[group('INSTALL')]
install-pi:
	bun add -g --ignore-scripts @earendil-works/pi-coding-agent

# install deno via mise. pins the resolved version into ~/.config/mise/config.toml
# (which link.sh symlinks to mise/config.toml in this repo — committed).
[group('INSTALL')]
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

# install bun via mise. pins the resolved version into ~/.config/mise/config.toml
[group('INSTALL')]
install-bun:
	#!/usr/bin/env zsh
	set -e
	if ! command -v mise >/dev/null 2>&1; then
		echo 'error: mise not on PATH' >&2
		exit 1
	fi
	mise use --global bun@latest
	mise install bun@latest
	mise reshim

# install python 3.14 via mise. pins the resolved version into
# ~/.config/mise/config.toml (link.sh symlinks it from mise/config.toml —
# committed). Ambient python for tooling; gcloud ships its own bundled
# interpreter and currently caps at python 3.13, so don't point gcloud
# at this via CLOUDSDK_PYTHON until upstream adds 3.14 support.
[group('INSTALL')]
install-python:
	#!/usr/bin/env zsh
	set -e
	if ! command -v mise >/dev/null 2>&1; then
		echo 'error: mise not on PATH' >&2
		exit 1
	fi
	mise use --global python@3.14
	mise install python@3.14
	mise reshim

# install cursor agent cli
[group('INSTALL')]
install-cursor:
	curl -fsS https://cursor.com/install | bash

# instal cursor origin (git) cli
[group('INSTALL')]
install-origin:
	curl -fsSL https://downloads.cursor.com/origin/install.sh | sh
	origin auth login

# install Vercel fx CLI
[group('INSTALL')]
install-fx:
	curl -fsSL https://fx.sh/setup.sh | bash

# install hermes agent
[group('INSTALL')]
install-hermes:
	curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# install Rust/ Cargo
[group('INSTALL')]
install-rust:
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# install Google Cloud CLI (gcloud) via the official upstream installer.
# non-interactive: --disable-prompts suppresses interactive questions. The
# installer only accepts --disable-prompts and --install-dir; anything else
# makes it print usage and exit 2. Usage reporting is opted out via the
# CLOUDSDK_CORE_DISABLE_USAGE_REPORTING env var, which install.sh honors.
# https://cloud.google.com/sdk/docs/install-sdk
[group('INSTALL')]
install-gcloud:
	CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true curl https://sdk.cloud.google.com | bash -s -- --disable-prompts
