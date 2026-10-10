#!/usr/bin/env bash
# Nightswim desktop: set the wallpaper. Safe to re-run.
# (The GNOME top panel is left alone; the terminal's own title bar is removed
#  via decorations = "None" in alacritty/alacritty.toml.)
set -euo pipefail
DOT="$(cd "$(dirname "$0")/.." && pwd)"
WALL="file://$DOT/nightswim/wallpaper/bg-term.png"

gsettings set org.gnome.desktop.background picture-uri "$WALL"
gsettings set org.gnome.desktop.background picture-uri-dark "$WALL"
gsettings set org.gnome.desktop.background picture-options zoom
