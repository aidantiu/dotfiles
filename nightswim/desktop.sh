#!/usr/bin/env bash
# Nightswim desktop: wallpaper + Super+Shift+N → `nsws toggle`. Safe to re-run.
# (The GNOME top panel is left alone; the terminal's own title bar is removed
#  via decorations = "None" in alacritty/alacritty.toml.)
set -euo pipefail
DOT="$(cd "$(dirname "$0")/.." && pwd)"
WALL="file://$DOT/nightswim/wallpaper/bg-term.png"

gsettings set org.gnome.desktop.background picture-uri "$WALL"
gsettings set org.gnome.desktop.background picture-uri-dark "$WALL"
gsettings set org.gnome.desktop.background picture-options zoom

# Super+Shift+N toggles whether new terminals open on their own workspace.
# Appended to the existing custom shortcuts, never replacing them.
KB=org.gnome.settings-daemon.plugins.media-keys
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/nightswim-nsws/
python3 -I - "$P" <<'PY2'
import ast, subprocess, sys
kb = "org.gnome.settings-daemon.plugins.media-keys"
cur = subprocess.run(["gsettings", "get", kb, "custom-keybindings"], capture_output=True, text=True).stdout.strip()
paths = ast.literal_eval(cur.replace("@as ", "")) if cur else []
if sys.argv[1] not in paths:
    subprocess.run(["gsettings", "set", kb, "custom-keybindings", str(paths + [sys.argv[1]])], check=True)
PY2
S="$KB.custom-keybinding:$P"
gsettings set "$S" name 'Nightswim: toggle new-terminal workspace'
gsettings set "$S" command "$HOME/.local/bin/nsws toggle"
gsettings set "$S" binding '<Shift><Super>n'
