#!/usr/bin/env bash
# Snapshot interactive+login bash (aliases, functions, PATH, env with hashed values)
# and tmux options/keys. Usage: snapshot.sh <out-prefix>
out=$1
for mode in ic lic; do
  bash -$mode 'alias; echo "##FUNCS"; declare -F; echo "##PATH"; echo "$PATH"; echo "##ENV"
    env -0 | sort -z | while IFS= read -r -d "" kv; do k=${kv%%=*}
      case $k in SHLVL|_|OLDPWD|PWD|SHELL_PID|STARSHIP_SESSION_KEY|BASH_EXECUTION_STRING) continue;; esac
      printf "%s=%s\n" "$k" "$(printf %s "${kv#*=}" | sha1sum | cut -c1-12)"; done' </dev/null 2>/dev/null > "$out.$mode"
done
tmux -L snap -f ~/.tmux.conf new-session -d -s s 2>/dev/null; sleep 2
tmux -L snap show -g 2>/dev/null | sort > "$out.tmux"
tmux -L snap list-keys 2>/dev/null | sort > "$out.tmuxkeys"
tmux -L snap kill-server 2>/dev/null
