#!/usr/bin/env bash
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
out=$(fastfetch --pipe false --config "$DOT/fastfetch/config.jsonc" 2>&1); rc=$?
check "exits 0" '[ $rc = 0 ]'
check "no config errors" '! grep -qi "error\|unknown\|invalid" <<<"$out"'
check "boxed sections" '[[ $out == *Software* && $out == *Hardware* ]]'
check "gold logo" '[[ $out == *"38;2;232;169;91m"* ]]'
check "icons are real glyphs" '[[ $out == *$'"'"''"'"'* ]]'
check "linked" '[ "$(readlink -f ~/.config/fastfetch/config.jsonc)" = "$DOT/fastfetch/config.jsonc" ]'
exit $fail
