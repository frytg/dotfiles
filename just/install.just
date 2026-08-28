# install NixOS
[group('SYSTEM')]
install-nix:
	# see https://nixos.org/download/
	sh <(curl -L https://nixos.org/nix/install)

# install PI.dev
[group('PI')]
install-pi:
	bun add -g --ignore-scripts @earendil-works/pi-coding-agent

# install cursor agent cli
[group('CURSOR')]
install-cursor:
	curl -fsS https://cursor.com/install | bash

# install Vercel fx CLI
[group('AI')]
install-fx:
	curl -fsSL https://fx.sh/setup.sh | bash
