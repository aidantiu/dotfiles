#!/usr/bin/env bash
# A newly opened Alacritty window must end up maximized (the WM ignores
# Alacritty's own startup_mode, so nightswim-automax does it).
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "automax service running" 'systemctl --user is-active --quiet nightswim-automax'
alacritty --title ns-automax-test -e sleep 6 >/dev/null 2>&1 &
sleep 3
state=$(xprop -name ns-automax-test _NET_WM_STATE 2>/dev/null)
wait
check "new Alacritty window is maximized" '[[ $state == *MAXIMIZED_VERT* && $state == *MAXIMIZED_HORZ* ]]'
exit $fail
