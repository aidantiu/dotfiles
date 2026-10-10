#!/usr/bin/env bash
# Tool colors + fastfetch autorun guards + delta/bat fallbacks.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ENV="$DOT/bash/nightswim-env.sh"

check "env file exists" '[ -f "$ENV" ]'
o=$(bash -ic ". '$ENV'; echo \"\$FZF_DEFAULT_OPTS|\$BAT_THEME|\$LS_COLORS\"; alias lt lx" 2>/dev/null </dev/null)
check "fzf colors" '[[ $o == *"pointer:#e8a95b"* ]]'
check "bat theme" '[[ $o == *"|Nightswim|"* ]]'
check "ls dirs lilac" '[[ $o == *"di=1;38;2;154;140;200"* ]]'
check "eza aliases" '[[ $o == *"alias lt="* && $o == *"alias lx="* ]]'
check "ls untouched" '[ "$(bash -ic ". '"'$ENV'"'; alias ls" 2>/dev/null </dev/null)" = "alias ls='"'ls --color=auto'"'" ]'

# fastfetch only in a top-level Alacritty shell, once
n=$(env -u TMUX ALACRITTY_WINDOW_ID=1 bash -ic ". '$ENV'; . '$ENV'" 2>/dev/null </dev/null | grep -c "Software")
check "fastfetch runs once in alacritty (re-source safe)" '[ "$n" = 1 ]'
n=$(TMUX=x ALACRITTY_WINDOW_ID=1 bash -ic ". '$ENV'" 2>/dev/null </dev/null | grep -c "Software")
check "no fastfetch inside tmux" '[ "$n" = 0 ]'
n=$(env -u TMUX -u ALACRITTY_WINDOW_ID bash -ic ". '$ENV'" 2>/dev/null </dev/null | grep -c "Software")
check "no fastfetch in other terminals" '[ "$n" = 0 ]'

# missing tools must not error (/bin == /usr/bin on Ubuntu, so build a minimal PATH)
bin=$(mktemp -d); trap 'rm -rf "$bin"' EXIT
for c in bash sh less cat; do ln -s "$(command -v $c)" "$bin/$c"; done
e=$(env -u TMUX ALACRITTY_WINDOW_ID=1 PATH="$bin" bash --norc -ic ". '$ENV'" 2>&1 </dev/null | grep -v "job control\|ioctl")
check "no errors when fastfetch/eza/batcat absent" '[ -z "$e" ]'
d=$(echo pager-ok | PATH="$bin" sh -c "$(git config core.pager)" 2>&1)
check "git pager falls back to less without delta" '[ "$d" = pager-ok ]'
d=$(echo pager-ok | sh -c "$(git config core.pager)" 2>&1)
check "git pager works with delta" '[[ $d == *pager-ok* ]]'
check "delta theme configured" '[ "$(git config delta.syntax-theme)" = Nightswim ]'
check "bat knows Nightswim" 'batcat --list-themes 2>/dev/null | grep -qx Nightswim'
exit $fail
