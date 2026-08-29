# first-time server setup: symlink configs, install deno + pi + fx, decrypt sops env.
# NixOS already provides herdr, mise, bun — these are the missing pieces.
# idempotent: re-run on an already-provisioned server to repair missing pieces.
[group('SERVER')]
install-server:
	just link-server
	just install-deno
	just install-pi
	just install-fx
	just --yes decrypt-env .pi/.env.personal.sops.yaml
	just --yes decrypt-env .pi/.env.work.sops.yaml

# refresh a provisioned server: update tools, re-link configs, re-decrypt env.
# skips `just brew`, `brew update/upgrade`, moshi-hook (brew services), and
# `just macos`. keeps mise, pi, bun, deno, rustup, gcloud, herdr, and sops
# env decryption. assumes mise + `just` are already installed.
[group('SERVER')]
update-server:
	@if ! command -v pi >/dev/null 2>&1; then just install-pi; fi
	just update-pi
	mise install
	just mise-update
	herdr server reload-config
	just link-server
	just --yes decrypt-env .pi/.env.personal.sops.yaml
	just --yes decrypt-env .pi/.env.work.sops.yaml
alias run-server := update-server

# symlink server config: herdr, just, agents skills, .pi.
# thin wrapper around bin/link-server.sh; useful standalone for repair.
[group('SERVER')]
link-server:
	zsh ./bin/link-server.sh
