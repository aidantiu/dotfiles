#!/usr/bin/env bash
# Desktop checks: palette loads, wallpaper set, GNOME panel left alone.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

. "$DOT/nightswim/palette.sh"
check "palette gold" '[ "$NS_GOLD" = e8a95b ]'
check "palette bg" '[ "$NS_BG" = 0e1328 ]'

WALL="file://$DOT/nightswim/wallpaper/bg-term.png"
check "wallpaper light" '[ "$(gsettings get org.gnome.desktop.background picture-uri)" = "'"'$WALL'"'" ]'
check "wallpaper dark"  '[ "$(gsettings get org.gnome.desktop.background picture-uri-dark)" = "'"'$WALL'"'" ]'

check "GNOME top panel untouched (no Hide Top Bar)" '! gnome-extensions list 2>/dev/null | grep -q hidetopbar'
exit $fail
