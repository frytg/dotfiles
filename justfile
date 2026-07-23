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
	pi update
	pi update --extensions
	-bun upgrade
	-deno upgrade
	-rustup update
	-gcloud components update --quiet
	herdr server reload-config
	-just macos
	just decrypt-env .pi/.env.personal.sops.yaml
	just decrypt-env .pi/.env.work.sops.yaml
alias install := run

# fetch, run all updates and link symlinks
[group('SYSTEM')]
up:
	git pull
	just run

[group('LOCAL')]
run-pi:
	just _env "pi"

# install NixOS
[group('SYSTEM')]
install-nix:
	# see https://nixos.org/download/
	sh <(curl -L https://nixos.org/nix/install)

# install PI.dev
[group('SYSTEM')]
install-pi:
	bun add -g --ignore-scripts @earendil-works/pi-coding-agent

[group('LINT')]
lint:
	biome check --fix

[group('LINT')]
format:
	tmp=$(mktemp) && cat .zed/settings.json | jq -S > "$tmp" && mv "$tmp" .zed/settings.json
	biome lint --write
	biome format --write

# sometimes colima needs to be reinstalled after clearing out old docker artifacts
[group('DOCKER')]
fix-colima:
	rm -rf ~/.colima/
	brew reinstall colima
	colima start

# login to UpCloud using a token
[group('UPCLOUD')]
upcloud-login token:
	echo {{ token }} | upctl account login --with-token

alias sshhosts := ssh-hosts

# edit local ssh known host config
[group('SSH')]
ssh-hosts:
	nano ~/.ssh/known_hosts

# list PGP keys and their fingerprints
[group('ENCRYPTION')]
list-pgp:
	gpg --list-keys

alias list-gpg := list-pgp
alias lpgp := list-pgp
alias lgpg := list-pgp

# create a new age encryption key into a given filename
[group('ENCRYPTION')]
create-age-key name="key":
	age-keygen -o "{{ name }}.txt"
	just create-public-key "{{ name }}"
	just age-key-to-1password "{{ name }}"

# create a public key from a given age key
[confirm]
[group('ENCRYPTION')]
create-public-key name="key":
	age-keygen -y "{{ name }}.txt" > "{{ name }}pub.txt"

# create a 1password key from a given age key
[confirm]
[group('ENCRYPTION')]
age-key-to-1password name:
	op document create "./{{ name }}.txt" --title "Age key > {{ name }}" --tags "age" --file-name "{{ name }}.txt"

## ---------------------------------
## ENCRYPTION shortcuts

# add/ remove keys (if .sops.yaml setup was changed)
[group('ENCRYPTION')]
update-keys:
	just _update-key .pi/.env.sops.yaml

_update-key file:
	sops updatekeys {{ file }}

# rotate keys (refreshed internal encryption keys)
[group('ENCRYPTION')]
rotate-keys:
	just _rotate-key .pi/.env.sops.yaml

_rotate-key file:
	sops rotate --in-place {{ file }}

# make changes to a secret file
[group('ENCRYPTION')]
edit-key file:
	EDITOR=nano sops edit {{ file }}

# decrypt a secret file
[confirm('This will overwrite any previously decrypted files, are you sure? (type `yes` to continue)')]
[group('ENCRYPTION')]
decrypt-key file:
	sops --output $(echo {{ file }} | sed 's/\.sops//g') --decrypt {{ file }}

# decrypt a secret file
[confirm('This will overwrite any previously decrypted files, are you sure? (type `yes` to continue)')]
[group('ENCRYPTION')]
decrypt-env file:
	sops --output-type dotenv --output $(echo {{ file }} | sed 's/\.sops.yaml//g') --decrypt {{ file }}
