#!/bin/zsh
set -e
set -x

# not to self: $(PWD) equals the absolute path to the directory of the script

# setup ghostty config
mkdir -p ~/.config/ghostty
ln -sf "$(PWD)/.ghostty" ~/.config/ghostty/config

# link basic config files to home dir
ln -sf "$(PWD)/.aliases" ~
ln -sf "$(PWD)/.bunfig.toml" ~
ln -sf "$(PWD)/.gitconfig" ~
ln -sf "$(PWD)/.zshrc" ~

# link vscode config
ln -sf "$(PWD)/.vscode/settings.json" ~/Library/Application\ Support/Cursor/User/settings.json
ln -sf "$(PWD)/.vscode/settings.json" ~/Library/Application\ Support/Code/User/settings.json

# setup ssh config
mkdir -p ~/.ssh
ln -sf "$(PWD)/.sshconfig" ~/.ssh/config
