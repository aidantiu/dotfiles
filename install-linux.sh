#!/usr/bin/env bash
# Symlink the Linux (Ubuntu) configs from this repo into $HOME.
# Existing real files are moved to ~/.dotfiles-backup-<timestamp>/ first.
# Safe to re-run. (setup.sh / `stow .` is the original macOS flow.)
set -euo pipefail

DOT="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

link() { # link <repo path> <target path>
  local src="$DOT/$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok      $dst"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/"; echo "backup  $dst -> $BACKUP/"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"; echo "link    $dst -> $src"
}

# bash
link bash/.bashrc        "$HOME/.bashrc"
link bash/.profile       "$HOME/.profile"
link bash/.bash_profile  "$HOME/.bash_profile"
link bash/bashconfigs    "$HOME/bashconfigs"
# zsh
link zshrc/.zshrc        "$HOME/.zshrc"
link zshrc/.zprofile     "$HOME/.zprofile"
# tmux (plugins stay in ~/.tmux/plugins, managed by tpm)
link tmux/tmux.conf      "$HOME/.tmux.conf"
# git (~/.gitconfig-work and ~/.git-credentials stay local)
link git/.gitconfig      "$HOME/.gitconfig"
link git/.config/git     "$HOME/.config/git"
# nvim
link nvim                "$HOME/.config/nvim"
# alacritty
link alacritty           "$HOME/.config/alacritty"
# bat (themes) — rebuild cache after linking
link bat                 "$HOME/.config/bat"
command -v batcat >/dev/null && batcat cache --build >/dev/null
# fastfetch
link fastfetch           "$HOME/.config/fastfetch"
# cava
link cava                "$HOME/.config/cava"

[ -f "$HOME/.secrets.sh" ] || echo "note: create ~/.secrets.sh for API keys (sourced by .bashrc, never committed)"
