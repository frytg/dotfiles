#!/bin/zsh
set -e
set -x

# not to self: $(PWD) equals the absolute path to the directory of the script

# setup ghostty config
mkdir -p ~/.config/ghostty
ln -sf "$(PWD)/.ghostty" ~/.config/ghostty/config

# link basic config files to home dir
ln -sf "$(PWD)/.aliases" ~
ln -sf "$(PWD)/.gitconfig" ~
ln -sf "$(PWD)/.zshrc" ~

# setup ssh config
mkdir -p ~/.ssh
ln -sf "$(PWD)/.sshconfig" ~/.ssh/config
