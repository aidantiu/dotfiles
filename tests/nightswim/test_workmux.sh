#!/usr/bin/env bash
# workmux: agent detection, web-aware layout wrapper, tmux integration.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fakebin() { mkdir -p "$tmp/bin$1"; for a in "${@:2}"; do printf '#!/bin/sh\n' > "$tmp/bin$1/$a"; chmod +x "$tmp/bin$1/$a"; done; }

fakebin 1 omp claude codex cursor-agent
PATH="$tmp/bin1:/usr/bin:/bin" "$DOT/bin/wm-agents" "$tmp/c1.yaml" >/dev/null
check "all four agents listed" 'for a in omp claude codex cursor; do grep -q "^  $a:" "$tmp/c1.yaml" || exit 1; done'
check "omp is default" 'grep -q "^agent: omp$" "$tmp/c1.yaml"'
fakebin 2 claude codex
PATH="$tmp/bin2:/usr/bin:/bin" "$DOT/bin/wm-agents" "$tmp/c2.yaml" >/dev/null
check "only installed agents" '! grep -qE "^  (omp|cursor):" "$tmp/c2.yaml" && grep -q "^  claude:" "$tmp/c2.yaml"'
check "claude default when no omp" 'grep -q "^agent: claude$" "$tmp/c2.yaml"'
check "valid YAML" 'python3 -I -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$tmp/c1.yaml"'
check "status_format off (keeps Nightswim pills)" 'grep -q "^status_format: false" "$tmp/c1.yaml"'
check "with-dev layout defined" 'grep -q "^  with-dev:" "$tmp/c1.yaml"'
check "live config generated" '[ -f ~/.config/workmux/config.yaml ] && grep -q "^agents:" ~/.config/workmux/config.yaml'
# wm: prints the workmux command it would run when WM_DRY_RUN=1
web="$tmp/web"; plain="$tmp/plain"
for r in "$web" "$plain"; do git init -q "$r"; done
echo '{"scripts":{"dev":"vite"}}' > "$web/package.json"
echo '{"scripts":{"build":"tsc"}}' > "$plain/package.json"
w() { (cd "$1" && WM_DRY_RUN=1 "$DOT/bin/wm" "${@:2}"); }
check "web repo: add gets -l with-dev" '[ "$(w "$web" add feat -p hi)" = "workmux add -l with-dev feat -p hi" ]'
check "non-web repo: plain add" '[ "$(w "$plain" add feat)" = "workmux add feat" ]'
check "explicit layout respected" '[ "$(w "$web" add feat -l solo)" = "workmux add feat -l solo" ]'
check "explicit agent: no layout (workmux forbids both)" '[ "$(w "$web" add feat -a claude)" = "workmux add feat -a claude" ]'
check "other subcommands pass through" '[ "$(w "$web" list)" = "workmux list" ]'
check "wm linked" '[ "$(readlink -f ~/.local/bin/wm)" = "$DOT/bin/wm" ]'
check "omp status hook installed" '[ -f ~/.omp/agent/extensions/workmux-status.ts ]'
exit $fail
