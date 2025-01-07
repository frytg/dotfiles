#!/bin/zsh
set -e

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# dotenvx
brew install dotenvx/brew/dotenvx

# Ghostty
brew install --cask ghostty

# other things
brew install \
	1password-cli \
	brotli \
	colima \
	ffmpeg \
	flyctl \
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
