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

# build precompiled zsh completions (saves ~5s per shell startup).
# best-effort: missing tools just mean the completion won't be available.
mkdir -p "$HOME/.zsh_completions"
if command -v kubectl >/dev/null 2>&1; then
  kubectl completion zsh > "$HOME/.zsh_completions/_kubectl" 2>/dev/null || true
fi

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
mkdir -p ~/.osaurus
ln -sfh "$(PWD)/skills" ~/.agents/skills
# ln -sfh "$(PWD)/skills" ~/.osaurus/skills
# ln -sfh "$(PWD)/.osaurus/slash-commands" ~/.osaurus/slash-commands

# link entire folder to ~/.dotfiles
ln -sfh "$(PWD)" ~/.dotfiles
