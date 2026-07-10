default:
	just --list

# run brew install and updates
[group('SYSTEM')]
brew:
	zsh ./install-brew.sh
	brew bundle

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

[group('SYSTEM')]
run:
	git pull
	zsh ./link.sh
	bun upgrade
	deno upgrade
	brew update
	brew upgrade
	just brew
	rustup update
	gcloud components update --quiet

	# Node/ nvm
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install 26
alias up := run
alias install := run

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

# decrypt a file using age
[group('ENCRYPTION')]
decrypt filename target AGE_KEY_PUB=".agekey.txt":
	age --decrypt -i "{{ AGE_KEY_PUB }}" --output "{{ target }}" "{{ filename }}"
