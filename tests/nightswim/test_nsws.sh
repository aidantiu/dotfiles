#!/usr/bin/env bash
# nsws: toggle whether new Alacritty windows get their own workspace.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp" NS_NOTIFY=0
N="$DOT/bin/nsws"; F="$tmp/nightswim/new-workspace"

check "default status is on" '[ "$("$N" status)" = on ]'
"$N" off >/dev/null; check "off writes flag" '[ "$(cat "$F")" = off ] && [ "$("$N" status)" = off ]'
"$N" toggle >/dev/null; check "toggle off→on" '[ "$("$N" status)" = on ]'
"$N" toggle >/dev/null; check "toggle on→off" '[ "$("$N" status)" = off ]'
"$N" on >/dev/null; check "on writes flag" '[ "$(cat "$F")" = on ]'
"$N" bogus >/dev/null 2>&1; rc=$?
check "bad argument → usage, exit 2" '[ $rc = 2 ]'
check "linked into ~/.local/bin" '[ "$(readlink -f ~/.local/bin/nsws)" = "$N" ]'
check "service reads the same flag" '[ "$(XDG_CONFIG_HOME="$tmp" /usr/bin/python3 -I -c "import sys; sys.path.insert(0, \"$DOT/nightswim\"); import automax; print(automax.FLAG)")" = "$F" ]'
shortcut_ok() (   # subshell: gsettings must see the real dconf, not the temp XDG_CONFIG_HOME
  unset XDG_CONFIG_HOME
  local kb=org.gnome.settings-daemon.plugins.media-keys p s
  for p in $(gsettings get $kb custom-keybindings | grep -o "/[^']*/"); do
    s="$kb.custom-keybinding:$p"
    [ "$(gsettings get "$s" binding)" = "'<Shift><Super>n'" ] &&
      [[ $(gsettings get "$s" command) == *"nsws toggle"* ]] && return 0
  done
  return 1
)
check "Super+Shift+N shortcut runs nsws toggle" shortcut_ok
exit $fail
