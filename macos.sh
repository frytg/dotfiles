#!/usr/bin/env bash
set -e
set -x

# check if homebrew is installed
if test ! $(which brew); then
  echo "Installing Homebrew for you."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# update homebrew
brew update
brew upgrade
