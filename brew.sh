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
	goat \
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
	restic \
	ruby \
	pyenv \
	rsync \
	scw \
	sops \
	valkey \
	yq

# UpCloud CLI
# https://upcloudltd.github.io/upcloud-cli/latest/
brew tap UpCloudLtd/tap
brew trust upcloudltd/tap
brew install upcloud-cli

# https://github.com/nubjs/nub
brew install nubjs/tap/nub

# https://github.com/syncthing/syncthing-macos
# https://formulae.brew.sh/cask/syncthing-app
# brew install --cask syncthing-app

# Terraform
brew tap hashicorp/tap
brew trust --formula hashicorp/tap/terraform
brew install hashicorp/tap/terraform

# git sync https://github.com/entireio/git-sync
brew tap entireio/tap
brew trust --cask entireio/tap/git-sync
brew install --cask git-sync

# dotenvx
brew trust dotenvx/brew/dotenvx
brew install --overwrite dotenvx/brew/dotenvx

# Ghostty
# brew reinstall --overwrite ghostty

# MQTT client (from EMQX)
brew trust --formula emqx/mqttx/mqttx-cli
brew install emqx/mqttx/mqttx-cli

# k9s
brew trust --formula derailed/k9s/k9s
brew install derailed/k9s/k9s

# tinygo
brew tap tinygo-org/tools
brew trust --formula tinygo-org/tools/tinygo
brew install tinygo

# Rust probe-rs
brew trust --formula probe-rs/probe-rs/probe-rs
brew tap probe-rs/probe-rs
brew install probe-rs

# Mino client
brew trust --formula minio/stable/mc
brew install minio/stable/mc
