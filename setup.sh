#!/usr/bin/env bash
stow .

# Herdr and micro write runtime state (sockets, sessions, backups) beside their
# config, so link individual files instead of letting stow fold the folders.
DOT="$(cd "$(dirname "$0")" && pwd)"
link() { # link <repo path> <target path>; never overwrites an existing file
  [ -e "$2" ] || [ -L "$2" ] && { echo "skip    $2 (exists)"; return; }
  mkdir -p "$(dirname "$2")" && ln -s "$DOT/$1" "$2" && echo "link    $2"
}
link herdr/config.toml "$HOME/.config/herdr/config.toml"
link micro/settings.json "$HOME/.config/micro/settings.json"
link micro/bindings.json "$HOME/.config/micro/bindings.json"
link micro/colorschemes/nightswim.micro "$HOME/.config/micro/colorschemes/nightswim.micro"
link bin/hd "$HOME/.local/bin/hd"
