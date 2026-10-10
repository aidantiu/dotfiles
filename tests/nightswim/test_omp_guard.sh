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
EOM
# MODEL_GUARD_EXT lets the harness itself be proven with a stand-in extension.
printf 'extensions:\n  - %s\n' "${MODEL_GUARD_EXT:-$DOT/omp/extensions/model-guard.ts}" > "$PI_CODING_AGENT_DIR/config.yml"
E="node $DOT/tests/omp/rpc_e2e.mjs"; F=fakeco/fake-fable-5
reqs() { grep -c "$1" "$tmp/req.log" 2>/dev/null || echo 0; }

: > "$tmp/req.log"; o=$($E $F no "hello")
check "decline: asked once" '[[ $o == *"\"confirms\":1"* ]]'
check "decline: fable never called" '[ "$(reqs fake-fable-5)" = 0 ]'
check "decline: switched to fallback (fake-mini)" '[[ $o == *"\"finalModel\":\"fakeco/fake-mini\""* ]]'

: > "$tmp/req.log"; o=$($E $F yes "one" "two")
check "accept: asked once for two messages" '[[ $o == *"\"confirms\":1"* ]]'
check "accept: fable called" '[ "$(reqs fake-fable-5)" -ge 2 ]'

: > "$tmp/req.log"; o=$($E fakeco/fake-mini "" "hi")
check "unrestricted model: no question" '[[ $o == *"\"confirms\":0"* ]] && [ "$(reqs fake-mini)" -ge 1 ]'

: > "$tmp/req.log"; o=$($E $F "" "hi" --no-ui)
check "no UI: restricted model never called" '[ "$(reqs fake-fable-5)" = 0 ]'

: > "$tmp/req.log"; timeout 60 omp -p --no-session --model $F "hi" >/dev/null 2>&1
check "print mode (-p): restricted model never called" '[ "$(reqs fake-fable-5)" = 0 ]'

: > "$tmp/req.log"; o=$($E fakeco/fake-mini yes "hi" "/model fakeco/fake-fable-5" "again")
check "switch to fable mid-session: asks before use" '[[ $o == *"\"confirms\":1"* ]]'
exit $fail
