#!/usr/bin/env bash
# End-to-end: real omp + model-guard against a local fake provider (never a real API).
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
command -v omp >/dev/null || { echo "FAIL omp not installed"; exit 1; }
tmp=$(mktemp -d); trap 'kill $FP 2>/dev/null; rm -rf "$tmp"' EXIT
python3 -I "$DOT/tests/omp/fake_provider.py" "$tmp/port" "$tmp/req.log" & FP=$!
for i in $(seq 1 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
export PI_CODING_AGENT_DIR="$tmp/agent" MODEL_GUARD_CONFIG="$DOT/omp/model-guard.yml"
mkdir -p "$PI_CODING_AGENT_DIR"
cat > "$PI_CODING_AGENT_DIR/models.yml" <<EOM
providers:
  fakeco:
    baseUrl: http://127.0.0.1:$(cat "$tmp/port")/v1
    api: openai-completions
    apiKey: fake
    models:
      - { id: fake-fable-5, name: Fake Fable, cost: { input: 30, output: 150, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
      - { id: fake-sonnet, name: Fake Sonnet, cost: { input: 3, output: 15, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
      - { id: fake-mini, name: Fake Mini, cost: { input: 0.3, output: 1.5, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
  lonelyco:
    baseUrl: http://127.0.0.1:$(cat "$tmp/port")/v1
    api: openai-completions
    apiKey: fake
    models:
      - { id: lonely-fable, name: Lonely Fable, cost: { input: 30, output: 150, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
EOM
# MODEL_GUARD_EXT lets the harness itself be proven with a stand-in extension.
printf 'extensions:\n  - %s\n' "${MODEL_GUARD_EXT:-$DOT/omp/extensions/model-guard.ts}" > "$PI_CODING_AGENT_DIR/config.yml"
E="node $DOT/tests/omp/rpc_e2e.mjs"; F=fakeco/fake-fable-5
reqs() { local c; c=$(grep -c "$1" "$tmp/req.log" 2>/dev/null); echo "${c:-0}"; }

: > "$tmp/req.log"; o=$($E $F no "hello")
check "decline: asked once" '[[ $o == *"\"confirms\":1"* ]]'
check "decline: fable never called" '[ "$(reqs fake-fable-5)" = 0 ]'
check "decline: switched to fallback (fake-sonnet: priciest allowed, strictly cheaper)" '[[ $o == *"\"finalModel\":\"fakeco/fake-sonnet\""* ]]'

: > "$tmp/req.log"; o=$($E $F yes "one" "two")
check "accept: asked once for two messages" '[[ $o == *"\"confirms\":1"* ]]'
check "accept: fable called" '[ "$(reqs fake-fable-5)" -ge 2 ]'

: > "$tmp/req.log"; o=$($E fakeco/fake-mini "" "hi")
check "unrestricted model: no question" '[[ $o == *"\"confirms\":0"* ]] && [ "$(reqs fake-mini)" -ge 1 ]'

: > "$tmp/req.log"; o=$($E $F "" "hi" --no-ui)
check "no UI: restricted model never called" '[ "$(reqs fake-fable-5)" = 0 ]'

: > "$tmp/req.log"; timeout 60 omp -p --no-session --model $F "hi" >/dev/null 2>&1 </dev/null; rc=$?
check "print mode (-p): restricted model never called, fallback used" '[ "$(reqs fake-fable-5)" = 0 ] && [ "$(reqs fake-sonnet)" -ge 1 ] && [ $rc -ne 124 ]'

: > "$tmp/req.log"; timeout 60 omp -p --no-session --model lonelyco/lonely-fable "hi" >/dev/null 2>"$tmp/err" </dev/null; rc=$?
check "print mode, no fallback: lonely-fable never called, no hang" '[ "$(reqs lonely-fable)" = 0 ] && [ $rc -ne 124 ]'

: > "$tmp/req.log"; o=$($E fakeco/fake-mini yes "hi" "/model fakeco/fake-fable-5" "again")
check "switch to fable mid-session: asks before use" '[[ $o == *"\"confirms\":1"* ]]'

: > "$tmp/req.log"; o=$($E $F yes,yes "one" "/new" "two")
check "new session: asks again after approval" '[[ $o == *"\"confirms\":2"* ]]'

check "global config links to dotfiles" '[ "$(readlink -f ~/.omp/agent/config.yml)" = "$DOT/omp/config.yml" ]'
check "global config loads model-guard" 'grep -Eq "(~|$DOT)/(dotfiles/)?omp/extensions/model-guard.ts" "$DOT/omp/config.yml"'
check "orca extensions untouched" 'ls ~/.omp/agent/extensions/orca-agent-status.ts >/dev/null'

# Real config really loads the guard (omp only warns on a bad extension path). RPC, no prompt sent.
real_load() { (env -u PI_CODING_AGENT_DIR -u MODEL_GUARD_CONFIG "$@" timeout 60 node "$DOT/tests/omp/rpc_load.mjs" 2>&1); }
o=$(real_load); check "real omp: ready, no load warning/error on stderr or notify frames" '[[ $o == *"\"ready\":true"* ]] && ! grep -v "^{\"type\":\"available_commands_update\"" <<<"$o" | grep -Ei "model-guard|failed to load|extension.*(error|fail)" | grep -qv "^{\"ready\""'
check "real omp: model-guard extension loaded (its /model-guard command is registered)" '[[ $o == *"\"name\":\"model-guard\""* ]]'
exit $fail
