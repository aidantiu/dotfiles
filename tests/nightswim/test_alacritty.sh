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
exit $fail
