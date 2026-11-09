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
ln -sf "$(PWD)/.zshenv" ~
ln -sf "$(PWD)/.zprofile" ~
ln -sf "$(PWD)/.zshrc" ~

# mise global config — node version + idiomatic pin file support
mkdir -p ~/.config/mise
ln -sf "$(PWD)/mise/config.toml" ~/.config/mise/config.toml

# link the justfile to the global justfile location so `just --global-justfile`
mkdir -p ~/.config/just
ln -sf "$(PWD)/justfile" ~/.config/just/justfile

# link vscode config
mkdir -p ~/Library/Application\ Support/Cursor/User/
ln -sf "$(PWD)/.cursor/keybindings.json" ~/Library/Application\ Support/Cursor/User/keybindings.json
mkdir -p ~/.cursor
ln -sf "$(PWD)/.cursor/mcp.json" ~/.cursor/mcp.json
# A global-only filename avoids loading these hooks again as project hooks.
ln -sf "$(PWD)/.cursor/hooks.global.json" ~/.cursor/hooks.json
ln -sf "$(PWD)/.cursor/herdr-desktop-status.sh" ~/.cursor/herdr-desktop-status.sh
ln -sf "$(PWD)/.vscode/settings.json" ~/Library/Application\ Support/Cursor/User/settings.json
mkdir -p ~/Library/Application\ Support/Code/User/
ln -sf "$(PWD)/.vscode/settings.json" ~/Library/Application\ Support/Code/User/settings.json

# link .pi for some extensions; clear any stale real dir first so `ln -sf`
# replaces it instead of nesting a .pi/.pi self-loop inside it
# [[ -d ~/.pi && ! -L ~/.pi ]] && rm -rf ~/.pi
ln -sfh "$(PWD)/.pi" ~/.pi

# link zed config
mkdir -p ~/.config/zed
ln -sf "$(PWD)/.zed/settings.json" ~/.config/zed/settings.json
ln -sf "$(PWD)/.zed/keymap.json" ~/.config/zed/keymap.json
# ~/.config/zed/themes is often pre-created as an empty dir; remove it first
# so the symlink to .zed/themes replaces it instead of nesting inside.
rm -rf ~/.config/zed/themes
ln -sfn "$(PWD)/.zed/themes" ~/.config/zed/themes

# herdr-app config (the app rewrites everything else in this folder)
mkdir -p ~/.config/herdr-app/themes ~/.config/herdr-app/layouts ~/.config/herdr-app/mods/git-changes ~/.config/herdr-app/mods/usage \
	~/.config/herdr-app/mods/my-spaces ~/.config/herdr-app/mods/my-agents
ln -sf "$(PWD)/herdr-app/keys.json" ~/.config/herdr-app/keys.json
ln -sf "$(PWD)/herdr-app/settings.json" ~/.config/herdr-app/settings.json
ln -sf "$(PWD)/herdr-app/themes/dark-greeny.json" ~/.config/herdr-app/themes/dark-greeny.json
ln -sf "$(PWD)/herdr-app/layouts/dan.json" ~/.config/herdr-app/layouts/dan.json
for f in main.js mod.json changes.svg; do
	ln -sf "$(PWD)/herdr-app/mods/git-changes/$f" ~/.config/herdr-app/mods/git-changes/$f
done
# Copy the cloned list mods too: Herdr doesn't hot-reload a mod through a symlink.
for m in my-spaces my-agents; do
	for f in main.js mod.json; do
		target="$HOME/.config/herdr-app/mods/$m/$f"
		if [[ -L "$target" ]]; then rm "$target"; fi
		cp "$(PWD)/herdr-app/mods/$m/$f" "$target"
	done
done
# Copy the whole usage mod so imports and reloads use files inside Herdr's home.
for f in main.js mod.json factory-usage.js; do
	target="$HOME/.config/herdr-app/mods/usage/$f"
	# Replace links from earlier installs without copying through to the source.
	if [[ -L "$target" ]]; then rm "$target"; fi
	cp "$(PWD)/herdr-app/mods/usage/$f" "$target"
done

# 1password ssh agent: which vaults the desktop agent offers
mkdir -p ~/.config/1Password/ssh
ln -sf "$(PWD)/1password/ssh/agent.toml" ~/.config/1Password/ssh/agent.toml

# setup ssh config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ln -sf "$(PWD)/.sshconfig" ~/.ssh/config
# authorized_keys for incoming ssh connections (remote login)
ln -sf "$(PWD)/.ssh-authorized_keys" ~/.ssh/authorized_keys
chmod 600 "$(PWD)/.ssh-authorized_keys"

# fx global agent rules
mkdir -p ~/.fx
ln -sfh "$(PWD)/.agents/AGENTS.md" ~/.fx/AGENTS.md

# droid: shared settings, MCP servers, and global rules; keep auth, sessions, and local overrides on this host.
mkdir -p ~/.factory
ln -sf "$(PWD)/factory/settings.json" ~/.factory/settings.json
ln -sf "$(PWD)/factory/mcp.json" ~/.factory/mcp.json
ln -sf "$(PWD)/factory/statusline.sh" ~/.factory/statusline.sh
ln -sfh "$(PWD)/.agents/AGENTS.md" ~/.factory/AGENTS.md

# claude code: settings, keybindings, global rules (CLAUDE.md), and skills.
# lives in claude/ (not .claude/) so it isn't picked up as project settings here.
# ~/.claude itself stays a real dir — it also holds sessions, history, and plugins.
mkdir -p ~/.claude
ln -sf "$(PWD)/claude/settings.json" ~/.claude/settings.json
ln -sf "$(PWD)/claude/keybindings.json" ~/.claude/keybindings.json
ln -sf "$(PWD)/claude/statusline.sh" ~/.claude/statusline.sh
ln -sfh "$(PWD)/.agents/AGENTS.md" ~/.claude/CLAUDE.md
ln -sfh "$(PWD)/skills" ~/.claude/skills

# setup skills link; -h keeps `ln` from following an existing symlink at the target
mkdir -p ~/.agents
ln -sfh "$(PWD)/skills" ~/.agents/skills
mkdir -p ~/Downloads/_DEV/frytg-note-vault/.agents
ln -sfh ~/Downloads/_DEV/frytg-note-vault/_skills ~/Downloads/_DEV/frytg-note-vault/.agents/skills

# link k9s config (macOS path only — symlink the config file, not the whole
# k9s dir, which also contains k9s.log and per-host cluster context files)
mkdir -p ~/Library/Application\ Support/k9s
ln -sf "$(PWD)/k9s/config.yaml" ~/Library/Application\ Support/k9s/config.yaml

# link entire folder to ~/.dotfiles
ln -sfh "$(PWD)" ~/.dotfiles

# build precompiled zsh completions (saves ~5s per shell startup).
# best-effort: missing tools just mean the completion won't be available.
mkdir -p "$HOME/.zsh_completions"
if command -v kubectl >/dev/null 2>&1; then
  kubectl completion zsh > "$HOME/.zsh_completions/_kubectl" 2>/dev/null || true
fi
