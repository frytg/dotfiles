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

# link the justfile to the global justfile location so `just --global-justfile`
mkdir -p ~/.config/just
ln -sf "$(PWD)/justfile" ~/.config/just/justfile

# link vscode config
ln -sf "$(PWD)/.vscode/settings.json" ~/Library/Application\ Support/Cursor/User/settings.json
ln -sf "$(PWD)/.vscode/settings.json" ~/Library/Application\ Support/Code/User/settings.json

# link zed config
mkdir -p ~/.config/zed
ln -sf "$(PWD)/.zed/settings.json" ~/.config/zed/settings.json
ln -sf "$(PWD)/.zed/keymap.json" ~/.config/zed/keymap.json

# link pi.dev config
mkdir -p ~/.pi/agent
ln -sf "$(PWD)/.pi/settings.json" ~/.pi/agent/settings.json
ln -sf "$(PWD)/.agents/AGENTS.md" ~/.pi/agent/AGENTS.md

# setup ssh config
mkdir -p ~/.ssh
ln -sf "$(PWD)/.sshconfig" ~/.ssh/config

# setup skills link; -h keeps `ln` from following an existing symlink at the target
mkdir -p ~/.agents
ln -sfh "$(PWD)/skills" ~/.agents/skills

# link entire folder to ~/.dotfiles
ln -sf "$(PWD)" ~/.dotfiles
