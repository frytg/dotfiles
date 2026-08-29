#!/bin/zsh
set -e
set -x

# server-only symlinks: herdr config, justfile, agents skills, .pi.
# NixOS already provides herdr, mise, bun — this script wires the dotfiles
# config into ~/.config/{herdr,just}/ and into ~/.agents/skills, ~/.pi.
#
# assumes the working directory is the dotfiles repo root (just sets it
# automatically when invoked via `just link-server`).

# herdr config
mkdir -p ~/.config/herdr
ln -sf "$(PWD)/herdr/config.toml" ~/.config/herdr/config.toml

# link the justfile to the global justfile location so `just --global-justfile`
mkdir -p ~/.config/just
ln -sf "$(PWD)/justfile" ~/.config/just/justfile

# setup skills link
mkdir -p ~/.agents
ln -sfh "$(PWD)/skills" ~/.agents/skills

# link .pi for some extensions; clear any stale real dir first so `ln -sf`
# replaces it instead of nesting a .pi/.pi self-loop inside it
# [[ -d ~/.pi && ! -L ~/.pi ]] && rm -rf ~/.pi
ln -sfh "$(PWD)/.pi" ~/.pi

# link entire folder to ~/.dotfiles (handy for absolute-path references)
ln -sfh "$(PWD)" ~/.dotfiles
