#!/usr/bin/env bash
# Tests for bash/prompt.sh. Run: bash tests/nightswim/test_prompt.sh
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
render() { OUT="${PS1@P}"; }
GOLD='38;2;232;169;91m'; RED='38;2;201;86;107m'
G_BRANCH=$'\ue0a0' G_CLOCK=$'\uf017'
TITLE_NL=$'\a\n'   # end of title escape followed by a newline = blank line
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
PROMPT_COMMAND=
. "$DOT/bash/prompt.sh"

cd "$tmp"
true; _ns_prompt; render
check "first prompt has no leading blank line" '[[ $OUT != *"$TITLE_NL"* ]]'
check "path shown" '[[ $OUT == *"${tmp##*/}"* ]]'
check "no git segment outside repo" '[[ $OUT != *"$G_BRANCH"* ]]'
check "gold arrow after success" '[[ $OUT == *"$GOLD"*"❯"* ]]'
false; _ns_prompt; render
check "red arrow after failure" '[[ $OUT == *"$RED"*"❯"* ]]'
check "blank line before later prompts" '[[ $OUT == *"$TITLE_NL"* ]]'

git init -q -b main repo && cd repo && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
_ns_prompt; render
check "branch shown" '[[ $OUT == *"$G_BRANCH main"* ]]'
check "clean repo: no dirty dot" '[[ $OUT != *"●"* ]]'
echo a > f && git add f
_ns_prompt; render
check "dirty dot shown" '[[ $OUT == *"●"* ]]'
git checkout -q -b '$(id>pwned)'   # git forbids spaces in ref names
_ns_prompt; render
check "malicious branch shown, not executed" '[ ! -e pwned ] && [[ $OUT == *"\$(id>pwned)"* ]]'

VIRTUAL_ENV=/x/.venv _ns_prompt; render
check "venv shown" '[[ $OUT == *"(.venv)"* ]]'
_ns_prompt; render
check "venv gone when unset" '[[ $OUT != *"(.venv)"* ]]'

_ns_t0=$((SECONDS-5)); _ns_prompt; render
check "duration shown for 5s command" '[[ $OUT == *"$G_CLOCK 5s"* ]]'
: "${PS0@P}"; _ns_prompt; render
check "PS0 hook records start; short command hides duration" '[[ $OUT != *"$G_CLOCK"* ]]'

. "$DOT/bash/prompt.sh"
check "re-sourcing does not duplicate PROMPT_COMMAND" '[ "$(grep -o _ns_prompt <<<"$PROMPT_COMMAND" | wc -l)" = 1 ]'
check "_ns_prompt runs first (sees real exit status)" '[[ $PROMPT_COMMAND == _ns_prompt* ]]'
PROMPT_COMMAND=$'__bp_precmd_invoke_cmd\n_ns_prompt;__fig_post_prompt\n__bp_interactive_mode'   # bash-preexec (Kiro) layout
. "$DOT/bash/prompt.sh"
check "re-sourcing under bash-preexec does not duplicate" '[ "$(grep -o _ns_prompt <<<"$PROMPT_COMMAND" | wc -l)" = 1 ]'
exit $fail
