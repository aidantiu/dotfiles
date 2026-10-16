#!/usr/bin/env bash
# Nightswim GNOME: fetch everything the desktop rice needs, user-local, no sudo.
#   shell extensions (extensions.gnome.org, matched to the running shell),
#   adw-gtk3, WhiteSur icons, Future-cyan cursors, Adwaita Sans,
#   Vicinae, conky AppImage.
# Safe to re-run: present items are skipped (FORCE=1 refetches).
# Then run nightswim/desktop.sh to apply settings.
set -euo pipefail
DATA="$HOME/.local/share"
BIN="$HOME/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# ~/.icons rather than ~/.local/share/icons: both are on the icon/cursor
# search path, and the latter is sometimes root-owned from old sudo installs.
ICONS="$HOME/.icons"
mkdir -p "$DATA/themes" "$ICONS" "$DATA/fonts" "$BIN"
have() { [ -z "${FORCE:-}" ] && [ -e "$1" ]; }
say() { printf '\033[38;2;232;169;91m==>\033[0m %s\n' "$*"; }

# --- shell extensions -------------------------------------------------------
SHELL_VER=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
EXTS=(
  user-theme@gnome-shell-extensions.gcampax.github.com
  blur-my-shell@aunetx
  just-perfection-desktop@just-perfection
  kiwimenu@kemma
  vicinae@dagimg-dot   # clipboard + window APIs for Vicinae on Wayland
)
for uuid in "${EXTS[@]}"; do
  if have "$DATA/gnome-shell/extensions/$uuid"; then echo "ok      $uuid"; continue; fi
  url=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$SHELL_VER" |
        python3 -c 'import json,sys; print(json.load(sys.stdin)["download_url"])')
  curl -fsSL -o "$TMP/ext.zip" "https://extensions.gnome.org$url"
  gnome-extensions install --force "$TMP/ext.zip"
  say "installed $uuid"
done

# --- GTK3 theme that honours the libadwaita colour overrides ----------------
if ! have "$DATA/themes/adw-gtk3-dark"; then
  url=$(curl -fsSL https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest |
        python3 -c 'import json,sys; print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".tar.xz")))')
  curl -fsSL "$url" | tar -xJ -C "$DATA/themes"
  say "installed adw-gtk3"
fi

# --- WhiteSur icons ---------------------------------------------------------
if ! have "$ICONS/WhiteSur-dark"; then
  git clone -q --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme "$TMP/whitesur"
  (cd "$TMP/whitesur" && ./install.sh -d "$ICONS" >/dev/null)
  say "installed WhiteSur icons"
fi

# --- Future-cyan cursors (gnome-look p/1465392; GitHub mirror of the tarball)
if ! have "$ICONS/Future-cyan-cursors"; then
  rm -rf "$ICONS/Future-cyan-cursors"
  curl -fsSL https://github.com/RoccoRakete/future-cursors-cyan/raw/main/Future-cyan-cursors.tar.gz |
    tar -xz -C "$ICONS"
  say "installed Future-cyan cursors"
fi

# --- Adwaita Sans / Mono (GNOME 48 fonts, not packaged on 24.04) -------------
if ! have "$DATA/fonts/adwaita"; then
  ver=$(curl -fsSL https://download.gnome.org/sources/adwaita-fonts/cache.json |
        python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)[2]["adwaita-fonts"], key=lambda v: [int(x) for x in v.split(".")])[-1])')
  curl -fsSL "https://download.gnome.org/sources/adwaita-fonts/${ver%%.*}/adwaita-fonts-$ver.tar.xz" | tar -xJ -C "$TMP"
  mkdir -p "$DATA/fonts/adwaita"
  find "$TMP/adwaita-fonts-$ver" -name '*.ttf' -exec cp {} "$DATA/fonts/adwaita/" \;
  fc-cache -f "$DATA/fonts" >/dev/null
  say "installed Adwaita fonts $ver"
fi

# --- Vicinae launcher -------------------------------------------------------
VIC_UNIT="$DATA/systemd/user/vicinae.service"
if ! have "$BIN/vicinae" || [ ! -e "$VIC_UNIT" ]; then
  # The upstream script aborts at its icon step when ~/.local/share/icons is
  # root-owned; binaries are already in place by then, so finish the user
  # service ourselves (same substitution upstream does).
  curl -fsSL https://vicinae.com/install | bash -s -- --prefix "$HOME/.local" >/dev/null || true
  mkdir -p "$(dirname "$VIC_UNIT")"
  sed "s|ExecStart=vicinae|ExecStart=$BIN/vicinae|" \
    "$HOME/.local/lib/vicinae/usr/lib/systemd/user/vicinae.service" > "$VIC_UNIT"
  systemctl --user daemon-reload
  say "installed Vicinae"
fi

# --- conky (desktop widgets) -------------------------------------------------
if ! have "$BIN/conky"; then
  url=$(curl -fsSL https://api.github.com/repos/brndnmtthws/conky/releases/latest |
        python3 -c 'import json,sys; print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].startswith("conky-ubuntu-24.04-x86_64") and a["name"].endswith("-release.AppImage")))')
  curl -fsSL -o "$BIN/conky" "$url"
  chmod +x "$BIN/conky"
  say "installed conky"
fi
