#!/usr/bin/env bash
# cava has no config-check flag: run it in a throwaway tmux pane and look for errors.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "gradient colors" 'grep -q "gradient_color_4 = '"'#e8a95b'"'" "$DOT/cava/config"'
T="tmux -L nscava -f /dev/null"
# Run it the way the user does: through their interactive bash, inside a tmux-256color pane.
$T new-session -d -x 80 -y 20 "TERM=tmux-256color bash -ic 'cava -p $DOT/cava/config'; echo CAVA_EXITED; sleep 5"; sleep 4
pane=$($T capture-pane -p 2>/dev/null); $T kill-server 2>/dev/null
check "cava keeps running (no config error)" '! grep -qi "CAVA_EXITED\|error\|invalid\|could not" <<<"$pane"'
check "linked" '[ "$(readlink -f ~/.config/cava/config)" = "$DOT/cava/config" ]'
exit $fail
