#!/bin/zsh
set -e
set -x

# check if homebrew is installed
if test ! $(which brew); then
  echo "Installing Homebrew for you."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# main tools
brew install \
	1password-cli \
	age \
	biome \
	brotli \
	colima \
	cosign \
	crane \
	ffmpeg \
	flyctl \
	helm \
	htop \
	httpstat \
	hugo \
	hurl \
	hyperfine \
	jq \
	just \
	libpq \
	llama.cpp \
	mactop \
	miniconda \
	minijinja-cli \
	ouch \
	opentofu \
	pkl \
	rage \
	ruby \
	pyenv \
	rsync \
	scw \
	sops \
	valkey \
	yq

# https://github.com/syncthing/syncthing-macos
# https://formulae.brew.sh/cask/syncthing-app
brew install --cask syncthing-app

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# git sync https://github.com/entireio/git-sync
brew trust --cask entireio/tap/git-sync
brew tap entireio/tap
brew install --cask git-sync

# dotenvx
brew install dotenvx/brew/dotenvx

# Ghostty
brew install --cask ghostty

# MQTT client (from EMQX)
brew install emqx/mqttx/mqttx-cli

# k9s
brew install derailed/k9s/k9s

# tinygo
brew tap tinygo-org/tools
brew install tinygo

# Rust probe-rs
brew tap probe-rs/probe-rs
brew install probe-rs

# Mino client
brew install minio/stable/mc
