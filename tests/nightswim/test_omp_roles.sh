#!/usr/bin/env bash
# omp model roles + the custom frontend sub-agent.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
CFG="$DOT/omp/config.yml"
AG="$DOT/omp/agents/frontend.md"
role() { awk -v r="$1" '/^modelRoles:/{on=1; next} on && /^[^ ]/{on=0} on && $1 == r":" {print $2}' "$CFG"; }
front() { awk '/^---$/{n++; next} n==1' "$AG"; }   # frontmatter only

check "default: Opus 5.5 (medium)"   '[ "$(role default)" = anthropic/claude-opus-5-5:medium ]'
check "plan: Opus 5.5 (high)"        '[ "$(role plan)" = anthropic/claude-opus-5-5:high ]'
check "slow: Opus 5.5 (high)"        '[ "$(role slow)" = anthropic/claude-opus-5-5:high ]'
check "task: Sonnet 5.5"             '[ "$(role task)" = anthropic/claude-sonnet-5-5 ]'
check "smol: Cursor Composer (own pool)" '[ "$(role smol)" = cursor/composer-2.5-fast ]'
check "frontend: Sonnet 5.5"         '[ "$(role frontend)" = anthropic/claude-sonnet-5-5 ]'
check "no role on Fable (sub-agents can't approve it)" '! grep -qi fable <(awk "/^modelRoles:/,/^[^ m]/" "$CFG")'

check "frontend agent exists" '[ -f "$AG" ]'
check "frontend agent is named frontend" '[[ $(front) == *"name: frontend"* ]]'
check "frontend agent: @frontend first, Cursor Sonnet fallback" \
  '[[ $(front) == *"model:"*"\"@frontend\""*"\"cursor/claude-sonnet-5-5\""* ]]'
check "frontend agent has a description (how the main agent picks it)" '[[ $(front) == *"description: "?* ]]'
check "frontend agent has instructions" '[ -n "$(awk "/^---\$/{n++; next} n>=2" "$AG" | tr -d "[:space:]")" ]'

check "installer links omp/agents into ~/.omp/agent/agents" \
  'grep -qE "^link omp/agents +\"\\\$HOME/.omp/agent/agents\"" "$DOT/install-linux.sh"'
exit $fail
