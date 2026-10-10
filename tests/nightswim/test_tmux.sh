#!/usr/bin/env bash
# Start an isolated tmux server with the real config and inspect it.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
T="tmux -L nstest"
err=$(mktemp)
$T -f "$DOT/tmux/tmux.conf" new-session -d -s t 2>"$err"; sleep 2
g() { $T show -gv "$1" 2>/dev/null; }

check "config loads without errors" '[ ! -s "$err" ]'
check "prefix unchanged (C-s)" '[ "$(g prefix)" = C-s ]'
check "status on top" '[ "$(g status-position)" = top ]'
check "window list centered" '[ "$(g status-justify)" = centre ]'
check "transparent bar" '[[ $(g status-style) == *"bg=default"* ]]'
check "session pill lilac" '[[ $(g status-left) == *"#9a8cc8"*"#S"* ]]'
check "pill caps are real glyphs" '[[ $(g status-left) == *$'"'"''"'"'* ]]'
check "current window gold" '[[ $(g window-status-current-format) == *"#e8a95b"* ]]'
check "active border lilac" '[[ $(g pane-active-border-style) == *"#9a8cc8"* ]]'
check "catppuccin removed" '! $T show -g 2>/dev/null | grep -q "@catppuccin\|catppuccin-tmux"'
check "copy uses xclip" '$T list-keys -T copy-mode-vi y | grep -q xclip'
check "sessionx still bound" '[ "$(g @sessionx-bind)" = o ]'
$T kill-server 2>/dev/null; rm -f "$err"
exit $fail
