#!/usr/bin/env bash
# A newly opened Alacritty window must end up maximized (the WM ignores
# Alacritty's own startup_mode, so nightswim-automax does it), on a workspace
# of its own. Briefly switches workspaces, then restores the original one.
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "automax service running" 'systemctl --user is-active --quiet nightswim-automax'
Q="/usr/bin/python3 $(dirname "$0")/wnck_query.py"
orig=$(xprop -root _NET_CURRENT_DESKTOP | awk '{print $NF}')
alacritty --title ns-automax-test -e sleep 6 >/dev/null 2>&1 &
sleep 3
state=$(xprop -name ns-automax-test _NET_WM_STATE 2>/dev/null)
ws=$($Q state ns-automax-test)
wait
$Q activate "$orig"
check "new Alacritty window is maximized" '[[ $state == *MAXIMIZED_VERT* && $state == *MAXIMIZED_HORZ* ]]'
read -r active win others < <(sed -E 's/active=([-0-9]+) win=([-0-9]+) others=([0-9]+)/\1 \2 \3/' <<<"$ws")
check "opens on its own workspace" '[ "$others" = 0 ]'
check "switches to that workspace" '[ "$active" = "$win" ]'
check "moved off the busy starting workspace" '[ "$win" != "$orig" ]'
exit $fail
