#!/usr/bin/env bash
# Opt-in end-to-end: `wm add` in an isolated tmux server must start omp in the new pane.
# Not named test_*.sh so run_all.sh skips it: it launches a real omp TUI for a few
# seconds and takes ~20s. Sends NO message to the agent. Run: bash tests/nightswim/smoke_wm.sh
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); sock=wmsmoke$$
cleanup() { tmux -L $sock kill-server 2>/dev/null; rm -rf "$tmp"; }; trap cleanup EXIT
repo=$tmp/repo; git init -q "$repo" && git -C "$repo" commit -q --allow-empty -m init
tmux -L $sock -f ~/.tmux.conf new-session -d -s s0 -c "$repo" -x 200 -y 50; sleep 3
w0=$(tmux -L $sock display -p -t s0 "#{window_id}")  # shell window; never type into the agent window
tmux -L $sock send-keys -t "$w0" "wm add smoke-test > $tmp/add.out 2>&1 </dev/null; echo rc=\$? >> $tmp/add.out" Enter
for _ in $(seq 30); do grep -q '^rc=' "$tmp/add.out" 2>/dev/null && break; sleep 1; done
check "wm add succeeded" 'grep -q "^rc=0" "$tmp/add.out"'
check "worktree created" 'git -C "$repo" worktree list | grep -q smoke-test'
check "pane runs omp" '( for _ in $(seq 20); do tmux -L $sock list-panes -a -F "#{pane_current_command}" | grep -qx omp && exit 0; sleep 1; done; exit 1 )'
tmux -L $sock send-keys -t "$w0" "cd $repo; workmux remove -f smoke-test > $tmp/rm.out 2>&1; echo rc=\$? >> $tmp/rm.out" Enter
for _ in $(seq 20); do grep -q '^rc=' "$tmp/rm.out" 2>/dev/null && break; sleep 1; done
check "worktree gone" '! git -C "$repo" worktree list | grep -q smoke-test'
check "branch gone" '! git -C "$repo" branch --list smoke-test | grep -q .'
check "window gone" '[ "$(tmux -L $sock list-windows | wc -l)" = 1 ]'
exit $fail
