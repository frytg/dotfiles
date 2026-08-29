#!/bin/zsh
set -e
set -x

# server-only symlinks: herdr config, justfile, agents skills, .pi.
# NixOS already provides herdr, mise, bun — this script wires the dotfiles
# config into ~/.config/{herdr,just}/ and into ~/.agents/skills, ~/.pi.
#
# assumes the working directory is the dotfiles repo root (just sets it
# automatically when invoked via `just link-server`).
#
# uses ${PWD} (parameter expansion) and `ln -sfn` (GNU) so this works on
# Linux. the macOS bin/link.sh uses `$(PWD)` and `ln -sfh` (zsh-only) but
# those don't work on NixOS where zsh has no `PWD` builtin and GNU ln has
# no `-h` flag.

# herdr config
mkdir -p ~/.config/herdr
ln -sfn "${PWD}/herdr/config.toml" ~/.config/herdr/config.toml

# link the justfile to the global justfile location so `just --global-justfile`
mkdir -p ~/.config/just
ln -sfn "${PWD}/justfile" ~/.config/just/justfile

# setup skills link
mkdir -p ~/.agents
ln -sfn "${PWD}/skills" ~/.agents/skills

# link .pi for some extensions; -n keeps `ln` from following an existing
# symlink at the target (would otherwise nest .pi/.pi inside the old symlink)
ln -sfn "${PWD}/.pi" ~/.pi

# link entire folder to ~/.dotfiles (handy for absolute-path references)
ln -sfn "${PWD}" ~/.dotfiles
