# uzu: local inference engine by Mirai, built from source. See context/UZU.md.

# checkout lives next to the dotfiles repo unless UZU_DIR is set
UZU_DIR := env('UZU_DIR', justfile_directory() / '..' / 'uzu')
UZU_BIN := UZU_DIR / 'target' / 'release' / 'cli'
UZU_MODEL := env('UZU_MODEL', 'trymirai/Qwen3.6-27B-M')
UZU_PORT := env('UZU_PORT', '8000')

# the Mac app's CLI; the `tailscale` alias isn't visible to just
TAILSCALE := env('TAILSCALE', '/Applications/Tailscale.app/Contents/MacOS/Tailscale')
UZU_TS_SERVICE := 'svc:uzu'
UZU_TS_PORT := '8000'

# clone or pull uzu, ensure the Metal toolchain, and build the release CLI (see context/UZU.md)
[group('INSTALL')]
install-uzu:
	#!/usr/bin/env zsh
	set -e
	if [[ -d "{{ UZU_DIR }}/.git" ]]; then
		git -C "{{ UZU_DIR }}" pull --ff-only
	else
		git clone --depth 1 https://github.com/trymirai/uzu "{{ UZU_DIR }}"
	fi
	if ! xcrun metal --version >/dev/null 2>&1; then
		xcodebuild -downloadComponent MetalToolchain
	fi
	cd "{{ UZU_DIR }}"
	cargo build --release -p cli
	echo "ok: {{ UZU_BIN }}"

# interactive uzu chat with UZU_MODEL (downloads on first run; extra args go to the cli)
[group('UZU')]
uzu *args:
	"{{ UZU_BIN }}" --model "{{ UZU_MODEL }}" {{ args }}

# send one message to UZU_MODEL, stream the reply and stats, then exit
[group('UZU')]
uzu-ask message:
	"{{ UZU_BIN }}" --model "{{ UZU_MODEL }}" -m {{ quote(message) }}

# serve UZU_MODEL as an OpenAI-compatible API on 127.0.0.1:UZU_PORT
[group('UZU')]
uzu-serve port=UZU_PORT:
	"{{ UZU_BIN }}" server --model "{{ UZU_MODEL }}" --port {{ port }}

# list models in the uzu catalog
[group('UZU')]
uzu-models:
	"{{ UZU_BIN }}" list-models

# expose the uzu server as the tagged Tailscale Service svc:uzu over HTTPS (see context/UZU.md)
[group('UZU')]
uzu-tailscale:
	"{{ TAILSCALE }}" serve --service={{ UZU_TS_SERVICE }} --https={{ UZU_TS_PORT }} --yes http://127.0.0.1:{{ UZU_PORT }}
	"{{ TAILSCALE }}" serve status

# remove the svc:uzu Tailscale Service config from this machine
[group('UZU')]
uzu-tailscale-off:
	"{{ TAILSCALE }}" serve drain {{ UZU_TS_SERVICE }}
	"{{ TAILSCALE }}" serve clear {{ UZU_TS_SERVICE }}
