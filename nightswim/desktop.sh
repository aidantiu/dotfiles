#!/usr/bin/env bash
# Nightswim desktop: wallpaper + Hide Top Bar (GNOME 46). Safe to re-run.
set -euo pipefail
DOT="$(cd "$(dirname "$0")/.." && pwd)"
WALL="file://$DOT/nightswim/wallpaper/bg-term.png"

gsettings set org.gnome.desktop.background picture-uri "$WALL"
gsettings set org.gnome.desktop.background picture-uri-dark "$WALL"
gsettings set org.gnome.desktop.background picture-options zoom

UUID=hidetopbar@mathieu.bidon.ca
EXT="$HOME/.local/share/gnome-shell/extensions/$UUID"
if [ ! -d "$EXT" ]; then
  echo "Installing Hide Top Bar — click Install in the GNOME dialog"
  gdbus call --session --timeout 120 --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "$UUID" >/dev/null
fi
gnome-extensions enable "$UUID"

hs() { gsettings --schemadir "$EXT/schemas" set org.gnome.shell.extensions.hidetopbar "$@"; }
hs enable-intellihide false   # always hidden, not only when a window overlaps
hs mouse-sensitive true       # push mouse to top edge to reveal
hs show-in-overview true      # Super shows it
