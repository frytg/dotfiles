#!/bin/zsh
set -e

# Bun
bun upgrade

# Deno
deno upgrade

# Homebrew
brew update
brew upgrade

# Node/ nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install 20
nvm install 22

# gcloud
gcloud components update --quiet
