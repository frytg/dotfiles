# age key recipes (create, derive pubkey, push to 1password)
import 'just/age.just'
# pgp + sops helpers (decrypt, rotate, edit secret files)
import 'just/encryption.just'
# nostr key recipes (nsec/npub generation, push to 1password)
import 'just/nostr.just'

default:
	just --list

# use a default sops file, or allow to be overridden by SOPS_ENV_FILE environment variable
DEFAULT_SOPS_FILE := '.env.sops.yaml'
SELECTED_SOPS_FILE := env('SOPS_ENV_FILE', DEFAULT_SOPS_FILE)
CURRENT_NODE_VERSION := '26'

# run a command with the selected sops file (injecting environment variables)
_env *args:
	sops exec-env --same-process {{ SELECTED_SOPS_FILE }} "{{ args }}"

# provision ambient node via mise (install + global pin + reshim).
# peels off leftover nub node shims so `node` resolves through mise.
# https://mise.jdx.dev/lang/node.html
[group('SYSTEM')]
node:
	#!/usr/bin/env zsh
	set -e
	if ! command -v mise >/dev/null 2>&1; then
		echo 'error: mise not on PATH — run `just brew` first' >&2
		exit 1
	fi
	mise use --global node@{{ CURRENT_NODE_VERSION }}
	mise install node@{{ CURRENT_NODE_VERSION }}
	mise reshim
	if [[ -d "$HOME/.nub/node-shim" ]]; then
		rm -rf "$HOME/.nub/node-shim"
		echo "ok: removed ~/.nub/node-shim"
	fi
	echo "ok: node $(mise exec -- node -v) via $(mise which node)"

# run brew install and updates
[group('SYSTEM')]
brew:
	zsh ./install-brew.sh
	brew bundle

# fix zsh compinit "insecure directories" prompt
# Homebrew on macOS makes /opt/homebrew/share group-writable (drwxrwxr-x),
# which trips compaudit's security check and makes compinit prompt on startup.
# Run this if you see: "zsh compinit: insecure directories, run compaudit for list."
[group('SYSTEM')]
fix-zsh-completions:
	@if [ -d /opt/homebrew/share ]; then \
		chmod g-w /opt/homebrew/share && echo "ok: /opt/homebrew/share is no longer group-writable"; \
	else \
		echo "skipped: /opt/homebrew/share not found"; \
	fi
	rm -f "$HOME/.zcompdump"
	@echo "ok: removed ~/.zcompdump — compinit will rebuild it on next shell"

# rebuild zsh completion cache: ~/.zcompdump (parsed completions) and
# ~/.zsh_completions/_kubectl (precompiled, avoids 5s `kubectl completion`
# spawn on every shell). Run after installing new tools that ship completions
# or after upgrading kubectl.
[group('SYSTEM')]
refresh-completions:
	rm -f "$HOME/.zcompdump"
	mkdir -p "$HOME/.zsh_completions"
	@if command -v kubectl >/dev/null 2>&1; then \
		kubectl completion zsh > "$HOME/.zsh_completions/_kubectl" 2>/dev/null \
			&& echo "ok: rebuilt ~/.zsh_completions/_kubectl" \
			|| echo "warn: kubectl completion failed"; \
	else \
		echo "skipped: kubectl not on PATH"; \
	fi
	@echo "ok: removed ~/.zcompdump — compinit will rebuild it on next shell"

# one-time moshi-hook setup: pair with the Moshi iOS app, install agent hooks,
# start the daemon. Get the pairing token from Moshi app → Settings → Hooks.
# No tmux needed: moshi-hook auto-detects herdr sessions via $HERDR_ENV.
[group('SYSTEM')]
moshi-setup token:
	moshi-hook pair --token {{ token }}
	moshi-hook install
	brew services start moshi-hook
	moshi-hook status

[group('SYSTEM')]
clear:
	brew cleanup --prune-prefix
	brew cleanup -s
	-rm -rf "$(brew --cache)"
	-rm -rf /tmp/bun-*
	-rm -rf ~/.bun/install/cache
	-npm cache clean --force
	-npm cache verify
	-docker system prune -a --volumes
	-cargo clean
alias clean := clear

# setup symlinks
[group('SYSTEM')]
link:
	zsh ./link.sh

# setup macos defaults
[group('SYSTEM')]
macos:
	zsh ./macos.sh
	just macos-reload

# reload macos defaults
[confirm('This will reload macOS defaults, are you sure? (type `yes` to continue)')]
[group('SYSTEM')]
macos-reload:
	killall Finder
	killall Dock
	killall SystemUIServer
	herdr server stop

# keep the mac awake but lockable: never system-sleep, display may sleep,
# ssh sessions stay reachable. persists across reboots (pmset writes to nvram-backed prefs).
# lock with ctrl+cmd+q — locking does not sleep the machine.
[group('SYSTEM')]
mac-nosleep:
	#!/usr/bin/env zsh
	set -e
	sudo pmset -a sleep 0          # never system-sleep
	sudo pmset -a displaysleep 10  # display off after 10 min (ssh unaffected)
	sudo pmset -a tcpkeepalive 1   # keep network connections alive
	sudo pmset -a ttyskeepawake 1  # active ssh sessions prevent idle sleep
	sudo pmset -a womp 1           # wake on network access
	echo 'ok: pmset configured'
	pmset -g | grep -E 'sleep|displaysleep|tcpkeepalive|ttyskeepawake|womp'

# run all updates and link symlinks
[group('SYSTEM')]
run:
	just brew
	brew update
	brew upgrade --yes
	just link
	@if command -v moshi-hook >/dev/null 2>&1 && brew services list 2>/dev/null | grep -q '^moshi-hook .*started'; then brew services restart moshi-hook; fi
	just node
	@if ! command -v pi >/dev/null 2>&1; then just install-pi; fi
	just update-pi
	mise install
	-bun upgrade
	-deno upgrade
	-gcloud components update --quiet
	herdr server reload-config
	just --yes decrypt-env .pi/.env.personal.sops.yaml
	just --yes decrypt-env .pi/.env.work.sops.yaml
	-just macos
alias install := run

# like `just run` but without homebrew: provision a server from a fresh clone.
# skips `just brew`, `brew update/upgrade`, moshi-hook (brew services), and
# `just macos`. keeps mise, pi, bun, deno, rustup, gcloud, herdr, and sops
# env decryption. assumes mise + `just` are already installed.
[group('SYSTEM')]
run-server:
	just node
	@if ! command -v pi >/dev/null 2>&1; then just install-pi; fi
	pi update
	mise install
	pi update --extensions
	-bun upgrade
	-deno upgrade
	-rustup update
	-gcloud components update --quiet
	herdr server reload-config
	just --yes decrypt-env .pi/.env.personal.sops.yaml
	just --yes decrypt-env .pi/.env.work.sops.yaml

# fetch, run all updates and link symlinks
[group('SYSTEM')]
up:
	git pull
	just run

# update rust packages
[group('RUST')]
update-rust:
	-rustup update

# update pi and extensions
[group('PI')]
update-pi:
	pi update
	sleep 2
	dotenvx run -f ~/.dotfiles/.pi/.env.personal -- pi update --extensions

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
	curl https://cursor.com/install -fsS | bash

[group('LINT')]
lint:
	oxlint

[group('LINT')]
format:
	oxfmt

# login to UpCloud using a token
[group('UPCLOUD')]
upcloud-login token:
	echo {{ token }} | upctl account login --with-token

alias sshhosts := ssh-hosts

# edit local ssh known host config
[group('SSH')]
ssh-hosts:
	nano ~/.ssh/known_hosts
