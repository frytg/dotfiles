#!/bin/zsh
set -e

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# dotenvx
brew install dotenvx/brew/dotenvx

# Ghostty
brew install --cask ghostty

# MQTT client (from EMQX)
brew install emqx/mqttx/mqttx-cli

# other things
brew install \
	1password-cli \
	brotli \
	colima \
	ffmpeg \
	flyctl \
	helm \
	htop \
	hugo \
	hurl \
	hyperfine \
	jq \
	llama.cpp \
	pkl \
	ruby \
	pyenv \
	rsync \
	scw
