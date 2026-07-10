#!/bin/zsh
set -e
set -x

# cd to this script's directory so brew bundle finds ./Brewfile
cd "${0:A:h}"

# install Homebrew if missing
if test ! $(which brew); then
  echo "Installing Homebrew for you."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
