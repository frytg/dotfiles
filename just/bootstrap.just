# setup symlinks
[group('SYSTEM')]
link:
	zsh ./bin/link.sh

# remove legacy Claude Code MCP entries (see docs/MCP.md)
[group('SYSTEM')]
mcp:
	#!/usr/bin/env zsh
	set -e
	if ! command -v claude >/dev/null 2>&1; then
		echo 'skipped: claude not on PATH'
		exit 0
	fi
	for name in exa firecrawl github; do
		claude mcp remove -s user "$name" >/dev/null 2>&1 || true
	done
	claude mcp list

# run all updates and link symlinks
[group('SYSTEM')]
run:
	just brew
	brew update
	brew upgrade --yes
	just link
	just mcp
	just node
	@if ! command -v pi >/dev/null 2>&1; then just install-pi; fi
	just update-pi
	-agent update
	-claude upgrade
	-droid update
	mise install
	just mise-update
	-bun upgrade
	-gcloud components update --quiet
	-hc update
	just --yes decrypt-env .pi/.env.personal.sops.yaml
	container system start
	-just macos
alias install := run

# fetch, run all updates and link symlinks
[group('SYSTEM')]
up:
	git pull
	just run
