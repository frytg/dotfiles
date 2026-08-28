# machine bootstrap recipes (link, run, up — symlinks + sync the dotfiles)
import 'just/bootstrap.just'

# one-shot installer recipes for cli tools (nix, pi, cursor, fx)
import 'just/install.just'

# macos-specific tweaks (defaults, reload, pmset)
import 'just/mac.just'

# headless server provisioning from a fresh clone (no homebrew, no macos)
import 'just/server.just'

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

# run brew install and updates. installs Homebrew if missing, then applies the Brewfile.
[group('SYSTEM')]
brew:
	#!/usr/bin/env zsh
	set -e
	if ! command -v brew >/dev/null 2>&1; then
		echo 'Installing Homebrew for you.'
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
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

# push local skills/ to an open webui instance via its REST API. --prune to delete remote skills, --dry-run to plan
[group('SKILLS')]
sync-skills *args:
	SOPS_ENV_FILE=.env.owui.sops.yaml just _env bun run bin/sync-skills.ts {{ args }}

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
