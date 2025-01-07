#!/bin/zsh
set -e

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Ghostty
brew install --cask ghostty

# other things
brew install \
	1password-cli \
	brotli \
	colima \
	ffmpeg \
	hugo \
	hurl \
	jq \
	llama.cpp \
	pkl \
	ruby \
	pyenv \
	rsync
