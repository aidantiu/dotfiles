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
sl() { $T display -p -t t '#{E:status-left}'; }
check "session pill lilac" '[[ $(sl) == *"#9a8cc8"* && $(g status-left) == *"#S"* ]]'
check "pill turns pink on prefix" '[[ $(g @ns_pill) == *"client_prefix,#d79bc9"* ]]'
$T copy-mode -t t; sleep 0.2
check "pill turns cyan in copy mode" '[[ $(sl) == *"#8cc4d4"* && $(sl) != *"#9a8cc8"* ]]'
$T send-keys -t t -X cancel; sleep 0.2
check "pill caps are real glyphs" '[[ $(g status-left) == *$'"'"''"'"'* ]]'
check "current window gold" '[[ $(g window-status-current-format) == *"#e8a95b"* ]]'
check "active border gold" '[[ $(g pane-active-border-style) == *"#e8a95b"* ]]'
check "heavy border lines" '[ "$(g pane-border-lines)" = heavy ]'
check "inactive panes dimmed (text only, bg stays transparent)" '[[ $(g window-style) == *"fg=#6b6f9a"* && $(g window-style) != *"bg=#"* ]]'
check "active pane full brightness" '[[ $(g window-active-style) == *"fg=#d6cfe8"* ]]'
check "active pane title is a gold pill" '[[ $(g pane-border-format) == *"pane_active"*"#e8a95b"* ]]'
check "single pane: no title strip" '[ "$($T show -wv -t t pane-border-status 2>/dev/null)" != top ]'
$T split-window -t t; sleep 0.3
check "after split: title strip on top" '[ "$($T show -wv -t t pane-border-status 2>/dev/null)" = top ]'
$T kill-pane -t t; sleep 0.3
check "back to one pane: strip gone" '[ "$($T show -wv -t t pane-border-status 2>/dev/null)" != top ]'
check "catppuccin removed" '! $T show -g 2>/dev/null | grep -q "@catppuccin\|catppuccin-tmux"'
check "copy uses xclip" '$T list-keys -T copy-mode-vi y | grep -q xclip'
check "sessionx still bound" '[ "$(g @sessionx-bind)" = o ]'
check "window pills show workmux status" '[[ $(g window-status-format) == *"@workmux_status"* && $(g window-status-current-format) == *"@workmux_status"* ]]'
check "prefix+w opens workmux dashboard" '$T list-keys -T prefix w | grep -q "workmux dashboard"'
check "prefix+W opens/switches to a wm dashboard window" '$T list-keys -T prefix W | grep -q "=wm" && $T list-keys -T prefix W | grep -q "workmux dashboard"'
$T kill-server 2>/dev/null; rm -f "$err"
exit $fail
