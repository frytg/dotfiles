#!/bin/zsh
# provision an ephemeral sandbox with the dotfiles environment.
# idempotent: safe to re-run on the same sandbox.
#
# pipe it into a fresh sandbox with `daytona exec NAME -- bash -s` or
# `nsc ssh NAME -- bash -s` from `just/sandbox.just`.
#
# customize via env (read at the top of the script):
#   DOTFILES_REPO — git URL of the dotfiles repo (default: https://tangled.org/frytg.digital/dotfiles)
#   DOTFILES_DIR  — where to clone the dotfiles (default: $HOME/.dotfiles)
#
# the bootstrap chain is forced into direct shell because no tools exist yet:
#   apt/apk/dnf → zsh/git/curl → mise → just (via mise) → clone → just * (everything else)

set -e

DOTFILES_REPO="${DOTFILES_REPO:-https://tangled.org/frytg.digital/dotfiles}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# most sandbox/container images run as root and don't ship sudo. only invoke
# sudo when we're not already root.
SUDO=''
if [[ "$(id -u)" -ne 0 ]]; then
	SUDO='sudo'
fi

echo '==> provisioning sandbox'

# --- bootstrap: system packages (no tools yet, can't be a just command) ---
echo '==> installing zsh, git, curl'
if command -v apt-get >/dev/null 2>&1; then
	$SUDO apt-get update -qq
	$SUDO apt-get install -y -qq zsh git curl
elif command -v apk >/dev/null 2>&1; then
	$SUDO apk add --no-cache zsh git curl bash
elif command -v dnf >/dev/null 2>&1; then
	$SUDO dnf install -y -q zsh git curl
else
	echo 'error: no supported package manager (apt/apk/dnf)' >&2
	exit 1
fi

# --- bootstrap: mise (no just yet, has to be direct shell) ---
echo '==> installing mise'
if ! command -v mise >/dev/null 2>&1; then
	curl -fsSL https://mise.run | sh
fi
# mise ships as a static binary in ~/.local/bin/mise. the install script
# adds it to ~/.bashrc/~/.zshrc but non-interactive shells don't source those,
# so we add ~/.local/bin to PATH explicitly and re-activate per command.
export PATH="$HOME/.local/bin:$PATH"
# export the shims dir explicitly — `eval "$(mise activate bash)"` is unreliable
# in the `bash -s` context that nsc/daytona use to pipe this script.
export PATH="$HOME/.local/share/mise/shims:$PATH"

# --- bootstrap: just via mise (chicken-and-egg: needs just to run just commands) ---
echo '==> installing just via mise'
mise use --global just@latest
mise install just@latest
mise reshim

# --- clone dotfiles (needs the repo before any just commands work) ---
echo "==> cloning dotfiles to $DOTFILES_DIR"
if [[ ! -d "$DOTFILES_DIR" ]]; then
	git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
	# pull latest so re-runs pick up justfile changes (e.g. new recipes).
	# --ff-only refuses to clobber local edits; if it fails, the user has
	# diverged and should resolve manually before re-provisioning.
	( cd "$DOTFILES_DIR" && git pull --ff-only )
fi

# trust the cloned repo's mise.toml — otherwise every mise invocation from
# inside the repo errors with "config file not trusted".
echo '==> trusting dotfiles mise.toml'
mise trust "$DOTFILES_DIR/mise.toml" 2>/dev/null || true

# --- everything below runs through just recipes from the dotfiles repo ---
cd "$DOTFILES_DIR"

# link server configs (herdr, justfile, agents skills, .pi)
echo '==> linking server configs'
just link-server

# install runtime toolchains via mise (bun, deno) — each pins a version into
# ~/.config/mise/config.toml (symlinked to mise/config.toml in this repo).
echo '==> installing bun, deno via just'
just install-bun
just install-deno
mise reshim

# install the pi agent (needs bun) and the fx CLI (curl pipe)
echo '==> installing pi, fx via just'
just install-pi
just install-fx

# --- default shell ---
# best-effort chsh; if /etc/shells doesn't list zsh yet, just exec zsh manually.
echo '==> setting zsh as default shell'
if [[ "$SHELL" != "$(command -v zsh)" ]] && command -v zsh >/dev/null 2>&1; then
	chsh -s "$(command -v zsh)" 2>/dev/null \
		|| echo '    (chsh failed — run `exec zsh` once you shell in)'
fi

# --- apply sandbox-specific rc files (zshrc, bashrc, profile) ---
# the rc files live alongside this script in sandbox/. they're designed for
# ephemeral sandboxes — minimal, opinionated, point at dotfiles-managed tools.
echo '==> applying sandbox rc files'
mkdir -p /etc/profile.d
# profile snippet is sourced by every login shell (sh, dash, bash -l, zsh -l)
install -m 0644 "$DOTFILES_DIR/sandbox/profile" /etc/profile.d/zz-dotfiles.sh
# zshrc + bashrc are symlinked so SSH sessions pick up aliases + mise activation
ln -sfn "$DOTFILES_DIR/sandbox/zshrc" "$HOME/.zshrc"
ln -sfn "$DOTFILES_DIR/sandbox/bashrc" "$HOME/.bashrc"

echo
echo "ok: sandbox provisioned. shell in with one of:"
echo "    just daytona-shell NAME"
echo "    just nsc-shell NAME"
