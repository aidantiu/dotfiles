#!/usr/bin/env bash
# The commit-msg hook strips AI-agent attribution; human co-authors stay.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git init -q -b main "$tmp/r" && cd "$tmp/r"
git config core.hooksPath "$DOT/.githooks"
git config user.name me; git config user.email me@example.com
msg=$'feat: thing\n\nBody line stays.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nCo-authored-by: GitHub Copilot <copilot@github.com>\nco-authored-by: Codex <codex@openai.com>\nCo-Authored-By: Jane Doe <jane@example.com>\n🤖 Generated with [Claude Code](https://claude.com/claude-code)'
git commit -q --allow-empty -m "$msg"
out=$(git log -1 --format=%B)
check "subject and body kept" '[[ $out == "feat: thing"*"Body line stays."* ]]'
check "Claude co-author removed" '[[ $out != *Claude* && $out != *anthropic* ]]'
check "Copilot / Codex removed" '[[ $out != *Copilot* && $out != *Codex* ]]'
check "human co-author kept" '[[ $out == *"Co-Authored-By: Jane Doe <jane@example.com>"* ]]'
raw_tail=$(git cat-file commit HEAD | tail -c 2 | od -An -c | tr -d ' ')
check "no trailing blank lines left behind" '[ "$raw_tail" != "\n\n" ]'
git commit -q --allow-empty -m $'fix: only agent trailer\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
check "agent-only trailer: no blank tail" '[ "$(git cat-file commit HEAD | sed "1,/^$/d")" = "fix: only agent trailer" ] && [ "$(git cat-file commit HEAD | tail -c 2 | od -An -c | tr -d " ")" != "\n\n" ]'
check "author is the user" '[ "$(git log -1 --format="%an <%ae>")" = "me <me@example.com>" ]'
check "dotfiles repo uses the hooks" '[ "$(git -C "$DOT" config core.hooksPath)" = .githooks ]'
exit $fail
