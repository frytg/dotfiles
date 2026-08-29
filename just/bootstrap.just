# setup symlinks
[group('SYSTEM')]
link:
	zsh ./bin/link.sh

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
	just mise-update
	-bun upgrade
	-deno upgrade
	-gcloud components update --quiet
	herdr server reload-config
	just --yes decrypt-env .pi/.env.personal.sops.yaml
	just --yes decrypt-env .pi/.env.work.sops.yaml
	-just macos
alias install := run

# fetch, run all updates and link symlinks
[group('SYSTEM')]
up:
	git pull
	just run
