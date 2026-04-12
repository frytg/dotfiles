# set default env vars
export DO_NOT_TRACK=1
export HOMEBREW_NO_ANALYTICS=1

# set backups buckets
export Y_BACKUP_REMOTE_BUCKET="frytg-remote-archive-2025-03"
export Y_BACKUP_MC_ALIAS="scwfr"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '$HOME/dev/google-cloud-sdk/path.zsh.inc' ]; then . '$HOME/dev/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '$HOME/dev/google-cloud-sdk/completion.zsh.inc' ]; then . '$HOME/dev/google-cloud-sdk/completion.zsh.inc'; fi

# nvm setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/versions/node/v15.4.0/bin:$HOME/dev/google-cloud-sdk/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PATH="/usr/local/opt/libpq/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
export GPG_TTY=$(tty)

# Scaleway CLI autocomplete initialization.
eval "$(scw autocomplete script shell=zsh)"

# Bun
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Deno
export PATH="$HOME/.deno/bin:$PATH"

# Rust/ Cargo
export PATH="$HOME/.cargo/bin:$PATH"

if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH=/opt/homebrew/opt/ruby/bin:$PATH
  export PATH=`gem environment gemdir`/bin:$PATH
  # eval "$(rbenv init - zsh)"
fi

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

source <(kubectl completion zsh)
source ~/.aliases

# bun completions
[ -s "/Users/dan/.bun/_bun" ] && source "/Users/dan/.bun/_bun"

# Tailscale CLI
# https://tailscale.com/kb/1080/cli?tab=macos
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# ESP32/ Rust-specific tooling
export PATH="$HOME/.rustup/toolchains/esp/xtensa-esp-elf/esp-14.2.0_20240906/xtensa-esp-elf/bin:$PATH"
export LIBCLANG_PATH="$HOME/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-18.1.2_20240912/esp-clang/lib"

# postgres
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/dan/.lmstudio/bin"
# End of LM Studio CLI section

# export PATH="$PATH:/opt/homebrew/Caskroom/miniconda/base/condabin/conda"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
