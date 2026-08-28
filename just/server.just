# like `just run` but without homebrew: provision a server from a fresh clone.
# skips `just brew`, `brew update/upgrade`, moshi-hook (brew services), and
# `just macos`. keeps mise, pi, bun, deno, rustup, gcloud, herdr, and sops
# env decryption. assumes mise + `just` are already installed.
[group('SERVER')]
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
