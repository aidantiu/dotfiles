#!/usr/bin/env bash
# dot: Nightswim shortcut cheat sheet.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
D="$DOT/bin/dot"

out=$("$D" 2>/dev/null); rc=$?
check "no args exit 0" '[ $rc = 0 ]'
help=$("$D" --help 2>/dev/null); hrc=$?
check "--help exit 0" '[ $hrc = 0 ]'
for s in "Super+," Super+Left Alt+F10 Ctrl+Shift+O Shift+Enter Super+Shift+N Ctrl+S prefix+w nsws \
         prefix+W "wm add" "workmux merge" "workmux rm" "workmux send" wm-agents \
         "omp -c" Alt+P Alt+M "/model-guard" "/git"; do
  check "no-args contains $s" '[[ $out == *"$s"* ]]'
  check "--help contains $s" '[[ $help == *"$s"* ]]'
done
"$D" --nope >/dev/null 2>&1; rc=$?
check "unknown arg exits non-zero" '[ $rc -ne 0 ]'
exit $fail
