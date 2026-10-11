#!/usr/bin/env bash
# Nightswim desktop: wallpaper, shell/GTK theme, icons, fonts, extensions,
# dock, Vicinae (Super+Space), conky widgets, Super+Shift+N → `nsws toggle`.
# Run nightswim/gnome/install.sh first (fetches the assets). Safe to re-run.
# Every run first snapshots the current desktop (nightswim/gnome/snapshot.sh);
# undo with `snapshot.sh restore <name>`, from a TTY if the screen is black.
# Extensions load on the next login. NEVER restart the shell from a script.
set -euo pipefail
DOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$DOT/nightswim/gnome/host-env.sh"
echo "snapshot: $("$DOT/nightswim/gnome/snapshot.sh" save pre-desktop)"
WALL="file://$DOT/nightswim/wallpaper/bg-term.png"
EXT="$HOME/.local/share/gnome-shell/extensions"

gsettings set org.gnome.desktop.background picture-uri "$WALL"
gsettings set org.gnome.desktop.background picture-uri-dark "$WALL"
gsettings set org.gnome.desktop.background picture-options zoom

# --- look: theme, icons, cursor, fonts -------------------------------------
python3 "$DOT/nightswim/gnome/shell-theme.py" >/dev/null
I=org.gnome.desktop.interface
gsettings set $I color-scheme prefer-dark
gsettings set $I gtk-theme adw-gtk3-dark
gsettings set $I icon-theme WhiteSur-dark
gsettings set $I cursor-theme Future-cyan-cursors
gsettings set $I font-name 'Adwaita Sans 11'
gsettings set $I document-font-name 'Adwaita Sans 11'
gsettings set $I monospace-font-name '0xProto Nerd Font Mono 11'
gsettings set $I clock-show-weekday true
gsettings set $I clock-show-date true
gsettings set $I show-battery-percentage true
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Adwaita Sans Bold 11'

# --- shell extensions ---------------------------------------------------------
NS_EXTS=(
  user-theme@gnome-shell-extensions.gcampax.github.com
  blur-my-shell@aunetx
  just-perfection-desktop@just-perfection
  weatheroclock@CleoMenezesJr.github.io
  kiwimenu@kemma
)
# Add to enabled-extensions (and drop from disabled) without touching others;
# works before the shell has loaded them, unlike `gnome-extensions enable`.
python3 -I - "${NS_EXTS[@]}" <<'PY'
import ast, subprocess, sys
def get(k):
    out = subprocess.run(["gsettings", "get", "org.gnome.shell", k], capture_output=True, text=True, check=True).stdout
    return ast.literal_eval(out.strip().replace("@as ", ""))
def put(k, v):
    subprocess.run(["gsettings", "set", "org.gnome.shell", k, str(v)], check=True)
on, off = get("enabled-extensions"), get("disabled-extensions")
put("enabled-extensions", on + [u for u in sys.argv[1:] if u not in on])
put("disabled-extensions", [u for u in off if u not in sys.argv[1:]])
PY
xs() { # xs <uuid> <schema> <key> <value>
  gsettings --schemadir "$EXT/$1/schemas" set "$2" "$3" "$4"
}
xs user-theme@gnome-shell-extensions.gcampax.github.com org.gnome.shell.extensions.user-theme name Nightswim

B=blur-my-shell@aunetx; BS=org.gnome.shell.extensions.blur-my-shell
xs $B $BS.panel blur true
xs $B $BS.panel static-blur true
xs $B $BS.panel override-background false     # keep the theme's navy tint
xs $B $BS.dash-to-dock blur true
xs $B $BS.dash-to-dock static-blur true
xs $B $BS.dash-to-dock override-background false
xs $B $BS.overview blur true
xs $B $BS.appfolder blur true

J=just-perfection-desktop@just-perfection; JS=org.gnome.shell.extensions.just-perfection
xs $J $JS startup-status 0                    # start on the desktop, not the overview
xs $J $JS workspace-popup false
xs $J $JS world-clock false
xs $J $JS accessibility-menu false
xs $J $JS clock-menu-position 0               # centre

xs weatheroclock@CleoMenezesJr.github.io org.gnome.shell.extensions.weather-oclock weather-after-clock true
xs kiwimenu@kemma org.gnome.shell.extensions.kiwimenu icon 0   # GNOME foot

# --- dock (Ubuntu Dock = Dash to Dock fork): floating, bottom, themed ------
# (No Vitals/System Monitor in the bar: Vitals coincided with the 2026-10-11
#  login hang; the conky System card shows CPU/RAM/disk/battery instead.)
D=org.gnome.shell.extensions.dash-to-dock
gsettings set $D dock-position BOTTOM
gsettings set $D extend-height false
# Hidden until the pointer hits the bottom edge, so maximized/fullscreen
# windows get the whole screen.
gsettings set $D dock-fixed false
gsettings set $D autohide true
gsettings set $D intellihide false
gsettings set $D autohide-in-fullscreen true
gsettings set $D dash-max-icon-size 40
gsettings set $D show-apps-at-top false
gsettings set $D show-mounts false
gsettings set $D apply-custom-theme true      # use the Nightswim shell CSS
gsettings set $D custom-theme-shrink true
gsettings set $D running-indicator-style DOTS

# --- custom shortcuts (appended, never replacing existing ones) -------------
KB=org.gnome.settings-daemon.plugins.media-keys
KBP=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
custom_key() { # custom_key <id> <name> <command> <binding>
  python3 -I - "$KBP/$1/" <<'PY'
import ast, subprocess, sys
kb = "org.gnome.settings-daemon.plugins.media-keys"
cur = subprocess.run(["gsettings", "get", kb, "custom-keybindings"], capture_output=True, text=True).stdout.strip()
paths = ast.literal_eval(cur.replace("@as ", "")) if cur else []
if sys.argv[1] not in paths:
    subprocess.run(["gsettings", "set", kb, "custom-keybindings", str(paths + [sys.argv[1]])], check=True)
PY
  local S="$KB.custom-keybinding:$KBP/$1/"
  gsettings set "$S" name "$2"
  gsettings set "$S" command "$3"
  gsettings set "$S" binding "$4"
}
# Super+Shift+N toggles whether new terminals open on their own workspace.
custom_key nightswim-nsws 'Nightswim: toggle new-terminal workspace' "$HOME/.local/bin/nsws toggle" '<Shift><Super>n'
# Super+Space opens Vicinae; input-source switching keeps the keyboard's own key.
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['XF86Keyboard']"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift>XF86Keyboard']"
custom_key nightswim-vicinae 'Nightswim: Vicinae launcher' "$HOME/.local/bin/vicinae toggle" '<Super>space'
systemctl --user enable --now vicinae.service >/dev/null 2>&1 || true

# --- conky widgets ---------------------------------------------------------------
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/nightswim-widgets.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Nightswim widgets
Comment=conky cards: GitHub contributions, calendar, system
Exec=sh -c 'sleep 4; exec $HOME/.local/bin/conky -c $DOT/nightswim/widgets/conky.conf'
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
pgrep -f "nightswim/widgets/conky.conf" >/dev/null ||
  (setsid "$HOME/.local/bin/conky" -c "$DOT/nightswim/widgets/conky.conf" >/dev/null 2>&1 &)
