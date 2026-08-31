# sandbox management — ephemeral Linux environments via Daytona or Namespace.
# two providers with parallel recipes:
#   daytona-* : cloud containers via `daytona` CLI (snapshots, container/VM classes)
#   nsc-*     : namespacelabs microVMs via `nsc` CLI (machine shapes, k3s optional)
#
# common workflow:
#   just daytona-up mybox       # spawn
#   just daytona-provision mybox # install dotfiles env (idempotent)
#   just daytona-shell mybox    # interactive SSH (with forwarded SSH agent)
#   just daytona-down mybox     # tear down
#
# namespace caveat: `nsc` uses UUIDs as instance identifiers, not the
# `--unique_tag` human handle. `nsc ssh <tag>` does NOT resolve the tag —
# it only takes the instance ID. so nsc-* recipes capture the ID via
# `--cidfile` at create time and look it up in $HOME/.cache/nsc/<name>.id.
#
# override defaults via env: DOTFILES_REPO, SANDBOX_TARGET, SANDBOX_SNAPSHOT, etc.

# ----- shared defaults -----
DOTFILES_REPO := env('DOTFILES_REPO', 'https://tangled.org/frytg.digital/dotfiles')
DEFAULT_SANDBOX_NAME := 'dotfiles-sandbox'
SANDBOX_TARGET := env('SANDBOX_TARGET', 'eu')
SANDBOX_SNAPSHOT := env('SANDBOX_SNAPSHOT', 'daytona-medium')
SANDBOX_MACHINE := env('SANDBOX_MACHINE', 'linux/amd64:2x8')
SANDBOX_DURATION := env('SANDBOX_DURATION', '60m')

# ============================================================
# Daytona
# ============================================================

# spawn a daytona sandbox. auto-stops after 30 min idle, auto-deletes 60 min later.
[group('SANDBOX')]
daytona-up name=DEFAULT_SANDBOX_NAME:
	#!/usr/bin/env zsh
	set -e
	if ! command -v daytona >/dev/null 2>&1; then
		echo 'error: daytona CLI not on PATH — install via `brew install daytonaio/cli/daytona`' >&2
		exit 1
	fi
	daytona create \
		--auto-stop 30 \
		--auto-delete 60 \
		--name "{{ name }}" \
		--target {{ SANDBOX_TARGET }} \
		--snapshot {{ SANDBOX_SNAPSHOT }}
	echo "ok: spawned daytona sandbox '{{ name }}'"

# spawn + provision in one step. convenience for the common workflow.
[group('SANDBOX')]
daytona-start name=DEFAULT_SANDBOX_NAME:
	just daytona-up "{{ name }}"
	just daytona-provision "{{ name }}"

# open an interactive shell in a daytona sandbox. SSH agent is forwarded automatically.
[group('SANDBOX')]
daytona-shell name=DEFAULT_SANDBOX_NAME:
	daytona ssh "{{ name }}"

# run a command inside a daytona sandbox (non-interactive).
[group('SANDBOX')]
daytona-exec name cmd:
	daytona exec "{{ name }}" -- {{ cmd }}

# show details for a daytona sandbox.
[group('SANDBOX')]
daytona-info name=DEFAULT_SANDBOX_NAME:
	daytona info "{{ name }}"

# list all daytona sandboxes in the workspace.
[group('SANDBOX')]
daytona-ls:
	daytona list

# delete a daytona sandbox permanently.
[group('SANDBOX')]
daytona-down name=DEFAULT_SANDBOX_NAME:
	daytona delete "{{ name }}"

# provision the dotfiles environment inside a daytona sandbox.
# pipes bin/provision-sandbox.sh to `bash -s` on the sandbox. idempotent.
# DOTFILES_REPO is interpolated by just (literal text, not shell var), and
# DOTFILES_DIR is left unset so the script defaults to its own $HOME/.dotfiles.
[group('SANDBOX')]
daytona-provision name=DEFAULT_SANDBOX_NAME:
	daytona exec "{{ name }}" -- env DOTFILES_REPO="{{ DOTFILES_REPO }}" bash -s \
		< ./bin/provision-sandbox.sh

# ============================================================
# Namespace (nsc)
# ============================================================

# resolve the cidfile path for a named sandbox
_nsc-cidfile name:
	@echo "$HOME/.cache/nsc/{{ name }}.id"

# resolve the instance id for a named sandbox; exit if the cidfile is missing
_nsc-id name:
	#!/usr/bin/env zsh
	set -e
	cidfile="$(just _nsc-cidfile {{ name }})"
	if [[ ! -f "$cidfile" ]]; then
		echo "error: no cidfile for '{{ name }}' at $cidfile — run \`just nsc-up {{ name }}\` first" >&2
		exit 1
	fi
	cat "$cidfile"

# spawn an ephemeral namespace instance with a user-friendly unique tag.
# writes the instance id to $HOME/.cache/nsc/<name>.id for lookup by
# other nsc-* recipes.
[group('SANDBOX')]
nsc-up name=DEFAULT_SANDBOX_NAME:
	#!/usr/bin/env zsh
	set -e
	if ! command -v nsc >/dev/null 2>&1; then
		echo 'error: nsc CLI not on PATH — install via `brew install namespacelabs/namespace/nsc`' >&2
		exit 1
	fi
	cidfile="$(just _nsc-cidfile {{ name }})"
	mkdir -p "${cidfile:h}"
	nsc create \
		--machine_type {{ SANDBOX_MACHINE }} \
		--unique_tag "{{ name }}" \
		--label "managed-by=just" \
		--label "name={{ name }}" \
		--ephemeral \
		--duration {{ SANDBOX_DURATION }} \
		--bare \
		--cidfile "$cidfile"
	echo "ok: spawned '{{ name }}' (id=$(cat "$cidfile"), auto-destructs in {{ SANDBOX_DURATION }})"

# spawn + provision in one step. convenience for the common workflow.
[group('SANDBOX')]
nsc-start name=DEFAULT_SANDBOX_NAME:
	just nsc-up "{{ name }}"
	just nsc-provision "{{ name }}"

# open an interactive shell in a namespace instance. SSH agent is forwarded.
[group('SANDBOX')]
nsc-shell name=DEFAULT_SANDBOX_NAME:
	nsc ssh "$(just _nsc-id {{ name }})"

# run a command in a namespace instance (non-interactive). stdin is forwarded.
[group('SANDBOX')]
nsc-exec name cmd:
	nsc ssh "$(just _nsc-id {{ name }})" -- {{ cmd }}

# show details for a namespace instance.
[group('SANDBOX')]
nsc-info name=DEFAULT_SANDBOX_NAME:
	nsc info "$(just _nsc-id {{ name }})"

# list namespace instances (default: filter to just-managed ones).
[group('SANDBOX')]
nsc-ls:
	nsc list --label "managed-by=just"

# destroy a namespace instance and clean up its cidfile.
[group('SANDBOX')]
nsc-down name=DEFAULT_SANDBOX_NAME:
	#!/usr/bin/env zsh
	set -e
	cidfile="$(just _nsc-cidfile {{ name }})"
	id="$(just _nsc-id {{ name }})"
	nsc destroy "$id" --force
	rm -f "$cidfile"
	echo "ok: destroyed '{{ name }}' (id=$id) and removed $cidfile"

# provision the dotfiles environment inside a namespace instance.
# pipes bin/provision-sandbox.sh to `bash -s` on the sandbox. idempotent.
# DOTFILES_REPO is interpolated by just (literal text, not shell var), and
# DOTFILES_DIR is left unset so the script defaults to its own $HOME/.dotfiles.
[group('SANDBOX')]
nsc-provision name=DEFAULT_SANDBOX_NAME:
	nsc ssh "$(just _nsc-id {{ name }})" -- env DOTFILES_REPO="{{ DOTFILES_REPO }}" bash -s \
		< ./bin/provision-sandbox.sh
