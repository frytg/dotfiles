# shell startup notes:
#   - Heavy work (conda, pyenv, scw autocomplete) is lazy-loaded
#     via wrapper functions. The real tool is loaded on first invocation.
#   - Node is managed by mise (not nvm/fnm/nub shim). See .agents/AGENTS.md
#     → "Runtimes". Interactive shells use `mise activate`; login shells
#     and IDEs get shims from .zprofile.
#   - kubectl completion is precompiled to ~/.zsh_completions/_kubectl by
#     link.sh, then picked up via fpath. Run `just refresh-completions`
#     to rebuild after upgrading kubectl.
#   - gem user bin path is cached in ~/.cache/zsh/gemdir (7d TTL) so we
#     don't spawn `gem environment` on every shell.
#   - After changing this file, run `just refresh-completions` to rebuild
#     ~/.zcompdump so new completions register.
# this file was optimized with pi

# ---- env vars ---------------------------------------------------------------

export DO_NOT_TRACK=1
export HOMEBREW_NO_ANALYTICS=1
export GPG_TTY=$(tty)

# ---- completion system ------------------------------------------------------

# Custom completions (precompiled kubectl, etc.) take precedence over Homebrew's.
fpath=("$HOME/.zsh_completions" "/opt/homebrew/share/zsh/site-functions" $fpath)
autoload -Uz compinit
# -C skips the security audit (Homebrew dirs are group-writable on macOS).
# compinit auto-rebuilds the dump if fpath entries are newer, so no manual
# check is needed. `just refresh-completions` forces a full rebuild.
compinit -d "$HOME/.zcompdump" -C

# ---- PATH -------------------------------------------------------------------

# One assignment per logical group, all relative to $PATH (no duplication).
# Order: Homebrew, system, language toolchains, project-local.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PATH="$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.deno/bin:$HOME/.local/bin:$HOME/.lmstudio/bin:$HOME/dev/google-cloud-sdk/bin:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:/opt/homebrew/opt/mysql-client/bin:/opt/homebrew/opt/ruby/bin:$PATH"

# Bun shell completion
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ---- gcloud -----------------------------------------------------------------

[ -f "$HOME/dev/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/dev/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/dev/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/dev/google-cloud-sdk/completion.zsh.inc"

# ---- ESP32 / Rust -----------------------------------------------------------

export PATH="$HOME/.rustup/toolchains/esp/xtensa-esp-elf/esp-14.2.0_20240906/xtensa-esp-elf/bin:$PATH"
export LIBCLANG_PATH="$HOME/.rustup/toolchains/esp-xtensa-esp32-elf-clang/esp-18.1.2_20240912/esp-clang/lib"

# ---- Ruby gem user bin (cached) ---------------------------------------------

# `gem environment gemdir` spawns a Ruby process; cache the result for a week.
_gemdir_cache="$HOME/.cache/zsh/gemdir"
if [[ ! -s "$_gemdir_cache" || -n "$_gemdir_cache"(#qN.mh+168) ]]; then
  mkdir -p "${_gemdir_cache:h}"
  command -v gem >/dev/null 2>&1 && gem environment gemdir >| "$_gemdir_cache" 2>/dev/null
fi
[[ -s "$_gemdir_cache" ]] && export PATH="$(<$_gemdir_cache)/bin:$PATH"
unset _gemdir_cache

# ---- pyenv (lazy) -----------------------------------------------------------

# Shims in PATH let `python`/`pip` work without loading pyenv init. The
# `pyenv` command itself is only initialised on first invocation.
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
[[ -d $PYENV_ROOT/shims ]] && export PATH="$PYENV_ROOT/shims:$PATH"
pyenv() {
  unfunction pyenv
  eval "$(pyenv init -)"
  pyenv "$@"
}

# ---- conda (lazy) -----------------------------------------------------------

# `conda init` ships a 1s shell hook. Wrap `conda` itself so the hook only
# runs when the user actually invokes conda. The hook is idempotent: re-
# entering doesn't stack PATH entries.
conda() {
  unfunction conda
  local __conda_setup
  __conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  elif [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
    . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
  else
    export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
  fi
  unset __conda_setup
  conda "$@"
}

# ---- scw (lazy autocomplete) -------------------------------------------------

# Only the completion script is expensive (~50ms); the `scw` binary itself
# stays a child process. Load the completion on first use.
scw() {
  unfunction scw
  eval "$(command scw autocomplete script shell=zsh)"
  scw "$@"
}

# ---- mise (node + other tools) ---------------------------------------------

# Activate after PATH is assembled so mise can prepend its tool dirs and re-
# resolve on chpwd (.node-version / .nvmrc / package.json#devEngines). Login
# shells already get shims from .zprofile for GUI/IDE contexts.
# https://mise.jdx.dev/getting-started.html#activate-mise
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# ---- aliases / user functions ----------------------------------------------

source ~/.aliases
