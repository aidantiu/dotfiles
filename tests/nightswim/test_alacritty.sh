#!/usr/bin/env bash
# Alacritty config parses, has Nightswim values, and loads without warnings.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
CFG="$DOT/alacritty/alacritty.toml"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "config exists" '[ -f "$CFG" ]'
check "toml values" 'python3 -I - "$CFG" <<"PY"
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
w, col = c["window"], c["colors"]
assert w["opacity"] == 0.82 and w["decorations"] == "None"
assert col["primary"]["background"] == "#0e1328"
assert col["cursor"]["cursor"] == "#e8a95b"
assert col["normal"]["yellow"] == "#e8a95b" and col["bright"]["black"] == "#3b4170"
assert c["font"]["normal"]["family"] == "0xProto Nerd Font Mono"
PY'
log=$(timeout 10 alacritty -vv --config-file "$CFG" -e true 2>&1)
check "no config errors/warnings" '! grep -qE "ERROR|WARN.*(config|Unused)" <<<"$log"'
check "linked into ~/.config" '[ "$(readlink -f ~/.config/alacritty/alacritty.toml)" = "$CFG" ]'
# A real window must ask the WM for no title bar (_MOTIF_WM_HINTS decorations = 0)
CFG_UNDER_TEST=${CFG_UNDER_TEST:-$CFG}
alacritty --config-file "$CFG_UNDER_TEST" --title ns-titlebar-test -e sleep 4 >/dev/null 2>&1 &
sleep 2
hints=$(xprop -name ns-titlebar-test _MOTIF_WM_HINTS 2>/dev/null)
wait
check "new window has no title bar" '[[ $hints == *"= 0x2, 0x0, 0x0"* ]]'
exit $fail
