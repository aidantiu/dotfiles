#!/usr/bin/env bash
# Snapshot / restore the GNOME desktop state the Nightswim rice touches.
#
#   snapshot.sh save <label>       -> ~/.nightswim-backups/<timestamp>-<label>/
#   snapshot.sh list
#   snapshot.sh restore <dir|name> (log out and back in afterwards)
#
# A snapshot holds:
#   dconf.ini   full `dconf dump /` (every GNOME setting, extensions, keybindings)
#   files.tar   the config paths in PATHS below that existed
#   absent      the PATHS that did not exist (restore deletes them)
#   inventory   names of installed extensions/themes/icons/fonts (reference only)
# Restore resets dconf to the snapshot exactly and puts PATHS back as they were.
# It never restarts GNOME Shell.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/host-env.sh"
ROOT="$HOME/.nightswim-backups"
# Relative to $HOME. Everything the rice writes outside of dconf.
PATHS=(
  .config/autostart/nightswim-widgets.desktop
  .config/gtk-3.0/gtk.css
  .config/gtk-4.0/gtk.css
  .config/vicinae
  .config/chromium/NativeMessagingHosts/com.vicinae.vicinae.json
  .config/systemd/user/graphical-session.target.wants/vicinae.service
  .config/systemd/user/nightswim-automax.service
  .local/share/systemd/user/vicinae.service
  .local/share/vicinae/themes/nightswim.toml
)

save() {
  local out="$ROOT/$(date +%Y%m%d-%H%M%S)-${1:?label}"
  mkdir -p "$out"
  dconf dump / > "$out/dconf.ini"
  local present=() p
  : > "$out/absent"
  for p in "${PATHS[@]}"; do
    if [ -e "$HOME/$p" ] || [ -L "$HOME/$p" ]; then present+=("$p"); else echo "$p" >> "$out/absent"; fi
  done
  tar -C "$HOME" -cf "$out/files.tar" --files-from /dev/null
  [ ${#present[@]} -eq 0 ] || tar -C "$HOME" -rf "$out/files.tar" "${present[@]}"
  {
    for d in .local/share/gnome-shell/extensions .local/share/themes .icons .local/share/icons .local/share/fonts; do
      echo "[$d]"; ls -1 "$HOME/$d" 2>/dev/null || true
    done
  } > "$out/inventory"
  echo "$out"
}

restore() {
  local src="${1:?snapshot dir or name}"
  [ -d "$src" ] || src="$ROOT/$src"
  [ -f "$src/dconf.ini" ] || { echo "not a snapshot: $src" >&2; exit 1; }
  # Safety net: snapshot the current state before overwriting it.
  echo "current state saved to $(save before-restore)"
  dconf reset -f /
  dconf load / < "$src/dconf.ini"
  local p
  while IFS= read -r p; do [ -n "$p" ] && rm -rf "${HOME:?}/$p"; done < "$src/absent"
  tar -tf "$src/files.tar" | grep -v '/$' | while IFS= read -r p; do rm -rf "${HOME:?}/$p"; done
  tar -C "$HOME" -xf "$src/files.tar"
  pkill -f 'nightswim/widgets/conky.conf' 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null || true
  echo "restored $src — log out and back in to finish"
}

case "${1:-}" in
  save) save "${2:-manual}" ;;
  list) ls -1 "$ROOT" 2>/dev/null ;;
  restore) restore "${2:-}" ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
