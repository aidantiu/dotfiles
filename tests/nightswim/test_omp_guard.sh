#!/usr/bin/env bash
# End-to-end: real omp + model-guard against a local fake provider (never a real API, never ~/.omp).
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
command -v omp >/dev/null || { echo "FAIL omp not installed"; exit 1; }
TM="tmux -L mguard$$ -f /dev/null"
tmp=$(mktemp -d); trap 'kill $FPS 2>/dev/null; $TM kill-server 2>/dev/null; rm -rf "$tmp"' EXIT
# mkagent <dir>: a temp agent dir + its own fake provider (log: <dir>/req.log).
mkagent() {
  mkdir -p "$1"; python3 -I "$DOT/tests/omp/fake_provider.py" "$1/port" "$1/req.log" & FPS+=" $!"
  for i in $(seq 1 50); do [ -s "$1/port" ] && break; sleep 0.1; done
  local url="http://127.0.0.1:$(cat "$1/port")/v1"
  cat > "$1/models.yml" <<EOM
providers:
  fakeco:
    baseUrl: $url
    api: openai-completions
    apiKey: fake
    models:
      - { id: fake-fable-5, name: Fake Fable, cost: { input: 30, output: 150, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
      - { id: fake-sonnet, name: Fake Sonnet, cost: { input: 3, output: 15, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
      - { id: fake-mini, name: Fake Mini, cost: { input: 0.3, output: 1.5, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
  lonelyco:
    baseUrl: $url
    api: openai-completions
    apiKey: fake
    models:
      - { id: lonely-fable, name: Lonely Fable, cost: { input: 30, output: 150, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
EOM
  # MODEL_GUARD_EXT lets the harness itself be proven with a stand-in extension.
  # The `task` role points at fable so a spawned sub-agent would use it; setupWizard off for the TUI cases.
  cat > "$1/config.yml" <<EOM
extensions:
  - ${MODEL_GUARD_EXT:-$DOT/omp/extensions/model-guard.ts}
modelRoles:
  task: fakeco/fake-fable-5
startup:
  setupWizard: false
EOM
}
FPS=""; mkagent "$tmp/agent"; mkagent "$tmp/tui"
export PI_CODING_AGENT_DIR="$tmp/agent" MODEL_GUARD_CONFIG="$DOT/omp/model-guard.yml" REQ_LOG="$tmp/agent/req.log"
E="node $DOT/tests/omp/rpc_e2e.mjs"; F=fakeco/fake-fable-5
reqs() { local c; c=$(grep -c "$1" "${2:-$REQ_LOG}" 2>/dev/null); echo "${c:-0}"; }
# The interactive cases need ~40s of wall clock (no human answers; the guard's 25s timeout must say No):
# start them first (own agent dir + fake provider) and check them at the end.
$TM new-session -d -s init -x 160 -y 40 -e PI_CODING_AGENT_DIR="$tmp/tui" -e MODEL_GUARD_CONFIG="$MODEL_GUARD_CONFIG" "omp --no-session --model $F 'hi from the cli'; sleep 600"
$TM new-session -d -s cont -x 160 -y 40 -e PI_CODING_AGENT_DIR="$tmp/tui" -e MODEL_GUARD_CONFIG="$MODEL_GUARD_CONFIG" "omp --no-session --model $F; sleep 600"
tui_start=$(date +%s); sleep 6; $TM send-keys -t cont c Enter; sleep 4
asked_init=$($TM capture-pane -p -t init | grep -c "Premium model"); asked_cont=$($TM capture-pane -p -t cont | grep -c "Premium model")

o=$($E $F no "hello")
check "decline: asked once" '[[ $o == *"\"confirms\":1"* ]]'
check "decline: fable never called" '[ "$(reqs fake-fable-5)" = 0 ]'
check "decline: switched to fallback (fake-sonnet: priciest allowed, strictly cheaper)" '[[ $o == *"\"finalModel\":\"fakeco/fake-sonnet\""* ]]'

o=$($E $F yes "one" "two")
check "accept: asked once for two messages" '[[ $o == *"\"confirms\":1"* ]]'
check "accept: fable called" '[[ $o == *"two -> completed [fable=2]"* ]]'

f0=$(reqs fake-fable-5); o=$($E fakeco/fake-mini "" "hi")
check "unrestricted model: no question" '[[ $o == *"\"confirms\":0"* ]] && [[ $o == *"hi -> completed [fable=$f0]"* ]]'

f0=$(reqs fake-fable-5); o=$($E $F "" "hi" --no-ui)
check "no UI: restricted model never called, no dialog, fallback used" '[ "$(reqs fake-fable-5)" = $f0 ] && [[ $o == *"\"confirms\":0"* ]] && [[ $o == *"\"finalModel\":\"fakeco/fake-sonnet\""* ]]'

: > "$REQ_LOG"; timeout 60 omp -p --no-session --model $F "hi" >/dev/null 2>&1 </dev/null; rc=$?
check "print mode (-p): restricted model never called, fallback used" '[ "$(reqs fake-fable-5)" = 0 ] && [ "$(reqs fake-sonnet)" -ge 1 ] && [ $rc -ne 124 ]'

: > "$REQ_LOG"; timeout 60 omp -p --no-session --model lonelyco/lonely-fable "hi" >/dev/null 2>"$tmp/err" </dev/null; rc=$?
check "print mode, no fallback: lonely-fable never called, no hang, abort message on stderr" '[ "$(reqs lonely-fable)" = 0 ] && [ $rc -ne 124 ] && grep -q "model-guard: .*Lonely Fable.*not sent" "$tmp/err"'

: > "$REQ_LOG"; timeout 60 omp --mode json -p "hi" --no-session --model $F >/dev/null 2>&1 </dev/null; rc=$?
check "json mode (-p): restricted model never called, fallback used" '[ "$(reqs fake-fable-5)" = 0 ] && [ "$(reqs fake-sonnet)" -ge 1 ] && [ $rc -ne 124 ]'

: > "$REQ_LOG"; timeout 60 omp --mode json -p "hi" --no-session --model lonelyco/lonely-fable >/dev/null 2>"$tmp/err" </dev/null; rc=$?
check "json mode, no fallback: lonely-fable never called, abort message on stderr" '[ "$(reqs lonely-fable)" = 0 ] && [ $rc -ne 124 ] && grep -q "model-guard: .*Lonely Fable.*not sent" "$tmp/err"'

: > "$REQ_LOG"; o=$($E fakeco/fake-mini yes "hi" "/model fakeco/fake-fable-5" "again")
check "switch to fable mid-session: asks after the switch, before use; fable called after yes" \
  '[[ $o == *"\"confirms\":1"* ]] && [[ $o == *"\"/model fakeco/fake-fable-5 -> ok [fable=0]\",\"confirm -> yes [fable=0]\",\"again -> completed [fable=1]\""* ]]'

: > "$REQ_LOG"; o=$($E fakeco/fake-mini no "hi" "/model fakeco/fake-fable-5" "c")
check "'c' after set_model to fable (RPC): asks, declined → fable never called" '[[ $o == *"\"confirms\":1"* ]] && [ "$(reqs fake-fable-5)" = 0 ]'

: > "$REQ_LOG"; o=$($E fakeco/fake-mini "" "hi" "/model fakeco/fake-fable-5" "/btw why" "/sleep 2")
check "backstop: side question (/btw) on unapproved fable makes no request and asks nothing" '[ "$(reqs fake-fable-5)" = 0 ] && [[ $o == *"\"confirms\":0"* ]] && [[ $o == *"\"btw:"* ]]'

: > "$REQ_LOG"; o=$($E $F yes,yes "one" "/new" "two")
check "new session: asks again after approval" '[[ $o == *"\"confirms\":2"* ]]'

: > "$REQ_LOG"; o=$($E fakeco/fake-mini no "SPAWN_TASK please" "/sleep 6")
check "sub-agent on @task role (fable) declined: asked once, fable never called" '[[ $o == *"\"confirms\":1"* ]] && [ "$(reqs fake-fable-5)" = 0 ] && [ "$(reqs fake-mini)" -ge 2 ]'
: > "$REQ_LOG"; o=$($E fakeco/fake-mini yes "SPAWN_TASK please" "/sleep 6")
check "sub-agent on @task role (fable) approved: asked once, child runs on fable (approval shared)" '[[ $o == *"\"confirms\":1"* ]] && [ "$(reqs fake-fable-5)" -ge 1 ]'
: > "$REQ_LOG"; o=$($E fakeco/fake-mini "" "SPAWN_TASK please" "/sleep 6" --no-ui)
check "sub-agent on @task role (fable), no UI: blocked, fable never called" '[[ $o == *"\"confirms\":0"* ]] && [ "$(reqs fake-fable-5)" = 0 ]'

# Interactive TUI (isolated tmux server), nobody answers: the dialog shows, times out as No (< omp's 30s handler timeout).
sleep $(( 36 - ($(date +%s) - tui_start) )) 2>/dev/null
check "TUI initial CLI prompt (omp 'msg', as workmux -p launches): asked" '[ "$asked_init" -ge 1 ]'
check "TUI 'c' continue (bypasses the input hook): asked" '[ "$asked_cont" -ge 1 ]'
check "TUI: no answer for 35s → fable never called (confirm timeout = No)" '[ "$(reqs fake-fable-5 "$tmp/tui/req.log")" = 0 ]'
$TM kill-server 2>/dev/null

check "global config links to dotfiles" '[ "$(readlink -f ~/.omp/agent/config.yml)" = "$DOT/omp/config.yml" ]'
check "global config loads model-guard" 'grep -Eq "(~|$DOT)/(dotfiles/)?omp/extensions/model-guard.ts" "$DOT/omp/config.yml"'
check "orca extensions untouched" 'ls ~/.omp/agent/extensions/orca-agent-status.ts >/dev/null'

# Real config really loads the guard (omp only warns on a bad extension path). RPC, no prompt sent.
real_load() { (env -u PI_CODING_AGENT_DIR -u MODEL_GUARD_CONFIG "$@" timeout 60 node "$DOT/tests/omp/rpc_load.mjs" 2>&1); }
o=$(real_load); check "real omp: ready, no load warning/error on stderr or notify frames" '[[ $o == *"\"ready\":true"* ]] && ! grep -v "^{\"type\":\"available_commands_update\"" <<<"$o" | grep -Ei "model-guard|failed to load|extension.*(error|fail)" | grep -qv "^{\"ready\""'
check "real omp: model-guard extension loaded (its /model-guard command is registered)" '[[ $o == *"\"name\":\"model-guard\""* ]]'
exit $fail
