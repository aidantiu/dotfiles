#!/usr/bin/env bash
# Tests for claude/statusline.sh (Claude Code statusLine command).
DOT=$(cd "$(dirname "$0")/../.." && pwd)
SL="$DOT/claude/statusline.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
bg() { printf '48;2;%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_CACHE_HOME="$tmp/cache" NS_RATE_API="http://127.0.0.1:9/" NS_ORCA_HOOK="$tmp/orca-hook.sh"
printf '#!/bin/sh\ncat > "%s/orca-got"\n' "$tmp" > "$NS_ORCA_HOOK"; chmod +x "$NS_ORCA_HOOK"

repo="$tmp/repo"; git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
payload() { # payload <used_pct>  (omit pct → no context_window field)
  local ctx=''
  [ -n "${1:-}" ] && ctx=',"context_window":{"context_window_size":200000,"used_percentage":'"$1"',"current_usage":{"input_tokens":50000,"output_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":9000}}'
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5.5","id":"claude-opus-5-5"},"cost":{"total_cost_usd":1.234},"rate_limits":{}%s}' "$repo" "$ctx"
}
run() { payload "$@" | bash "$SL" 2>&1; }

out=$(run 30)
check "model pill (lilac)" '[[ $out == *"$(bg 9a8cc8)"*"Opus 5.5"* ]]'
check "dir pill (blue)" '[[ $out == *"$(bg 8497d6)"*"repo"* ]]'
check "clean branch (green)" '[[ $out == *"$(bg 86b3a0)"*"main "* && $out != *"main*"* ]]'
check "context 30% (cyan)" '[[ $out == *"$(bg 8cc4d4)"*"60k/200k (30%)"* ]]'
check "rounded caps are real glyphs" '[[ $out == *$'"'"''"'"'* && $out == *$'"'"''"'"'* ]]'
check "no rate cached: USD with an icon" '[[ $out == *"$(bg bdb3d6)"*" \$1.23"* && $out != *"  \$1.23"* ]]'
check "no error text" '[[ $out != *"command not found"* && $out != *"syntax error"* ]]'

mkdir -p "$XDG_CACHE_HOME/claude-statusline"
printf '56 %s\n' "$(date +%s)" > "$XDG_CACHE_HOME/claude-statusline/usd-php"
out=$(run 30)
check "cached rate: pesos" '[[ $out == *"₱69.10"* ]]'

check "context 65% (gold)" '[[ $(run 65) == *"$(bg e8a95b)"*"(65%)"* ]]'
check "context 85% (red)" '[[ $(run 85) == *"$(bg c9566b)"*"(85%)"* ]]'
out=$(run)
check "missing context_window still renders" '[[ $out == *"Opus 5.5"* && $out != *"%)"* ]]'

echo x > "$repo/f"; git -C "$repo" add f; git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m f
before=$(stat -c %y "$repo/.git/index"); sleep 1.1; touch "$repo/f"
run 30 >/dev/null
check "never rewrites .git/index" '[ "$(stat -c %y "$repo/.git/index")" = "$before" ]'
echo y >> "$repo/f"
check "dirty branch (gold + *)" '[[ $(run 30) == *"$(bg e8a95b)"*"main*"* ]]'

rm -f "$tmp/orca-got"; run 30 >/dev/null; sleep 0.5
check "payload forwarded to Orca hook" '[ "$(cat "$tmp/orca-got" 2>/dev/null)" = "$(payload 30)" ]'

start=$(date +%s%N); run 30 >/dev/null; ms=$(( ($(date +%s%N) - start) / 1000000 ))
check "renders under 150ms (${ms}ms)" '[ "$ms" -lt 150 ]'
exit $fail
