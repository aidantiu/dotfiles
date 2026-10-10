#!/usr/bin/env bash
# Desktop checks: palette loads, wallpaper set, Hide Top Bar enabled + configured.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

. "$DOT/nightswim/palette.sh"
check "palette gold" '[ "$NS_GOLD" = e8a95b ]'
check "palette bg" '[ "$NS_BG" = 0e1328 ]'

WALL="file://$DOT/nightswim/wallpaper/bg-term.png"
check "wallpaper light" '[ "$(gsettings get org.gnome.desktop.background picture-uri)" = "'"'$WALL'"'" ]'
check "wallpaper dark"  '[ "$(gsettings get org.gnome.desktop.background picture-uri-dark)" = "'"'$WALL'"'" ]'

UUID=hidetopbar@mathieu.bidon.ca
EXT="$HOME/.local/share/gnome-shell/extensions/$UUID"
check "hidetopbar enabled" 'gnome-extensions info "$UUID" 2>/dev/null | grep -q "State: ACTIVE\|State: ENABLED"'
hs() { gsettings --schemadir "$EXT/schemas" get org.gnome.shell.extensions.hidetopbar "$1" 2>/dev/null; }
check "always hide (no intellihide)" '[ "$(hs enable-intellihide)" = false ]'
check "reveal on mouse" '[ "$(hs mouse-sensitive)" = true ]'
check "show in overview" '[ "$(hs show-in-overview)" = true ]'
exit $fail
