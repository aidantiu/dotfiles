#!/usr/bin/env bash
# Claude Code statusline — Nightswim pills, matching the tmux bar.
# Adapted from JoshuaHM-p4/dotfiles-fedora (claude/.claude/statusline-command.sh).
# Wired up in ~/.claude/settings.json: statusLine.command = bash ~/dotfiles/claude/statusline.sh
#
#   model  lilac | dir  blue | git  green (gold + * when dirty)
#   context  cyan → gold ≥60% → red ≥80% | cost  lavender (USD)
#
# Also forwards the payload to Orca's statusline hook (rate-limit tracking) in
# the background, since this replaces the statusLine Orca installed.

TEXT=0e1328
MODEL_BG=9a8cc8; DIR_BG=8497d6; GIT_BG=86b3a0; CTX_BG=8cc4d4
COST_BG=bdb3d6;  WARN_BG=e8a95b; ERR_BG=c9566b

# Nerd Font glyphs as escapes (literal private-use chars get mangled by editors)
CAP_L=$'' CAP_R=$'' SEP=$''
I_MODEL=$'' I_DIR=$'' I_GIT=$'' I_CTX=$'' I_USD=$''

input=$(cat)

# ---- Orca passthrough (never blocks the repaint) ---------------------------
ORCA_HOOK=${NS_ORCA_HOOK:-$HOME/.orca/agent-hooks/claude-statusline.sh}
if [ -x "$ORCA_HOOK" ]; then
    (printf '%s' "$input" | /bin/sh "$ORCA_HOOK" >/dev/null 2>&1 &) 2>/dev/null
fi

# ---- fields (one jq call; one field per line keeps empty ones in place) ----
mapfile -t f < <(printf '%s' "$input" | jq -r '
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // "?"),
    (.cost.total_cost_usd // 0),
    (.context_window.context_window_size // ""),
    (.context_window.used_percentage // ""),
    ((.context_window.current_usage // {})
      | (.input_tokens // 0) + (.output_tokens // 0)
      + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null)
cwd=${f[0]:-$PWD}; model=${f[1]:-?}; cost=${f[2]:-0}
win=${f[3]}; pct=${f[4]}; used=${f[5]:-0}
dir=${cwd/#$HOME/\~}

# ---- git (read-only: never rewrites .git/index, so no index.lock clashes) --
branch=""; dirty=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null) ||
        branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain --untracked-files=no 2>/dev/null | head -n1)" ] && dirty="*"
fi

# ---- context window --------------------------------------------------------
fmt_tok() { awk -v u="$1" 'BEGIN{
    if      (u >= 999500) printf "%.1fm", u/1000000
    else if (u >= 1000)   printf "%.0fk", u/1000
    else                  printf "%d", u }'; }
ctx=""; pct_r=""
if [ -n "$win" ] && [ -n "$pct" ] && [ "$used" != 0 ]; then
    pct_r=$(awk -v p="$pct" 'BEGIN{printf "%d", p+0.5}')
    ctx="$(fmt_tok "$used")/$(fmt_tok "$win") (${pct_r}%)"
fi

# ---- cost (USD, as Claude reports it) --------------------------------------
cost_txt=$(printf '$%.2f' "$cost")

# ---- segments --------------------------------------------------------------
icons=(); bases=(); txts=()
seg() { icons+=("$1"); bases+=("$2"); txts+=("$3"); }
seg "$I_MODEL" "$MODEL_BG" "$model"
seg "$I_DIR"   "$DIR_BG"   "$dir"
if [ -n "$branch" ]; then
    if [ -n "$dirty" ]; then seg "$I_GIT" "$WARN_BG" "${branch}${dirty}"
    else                     seg "$I_GIT" "$GIT_BG"  "$branch"; fi
fi
if [ -n "$ctx" ]; then
    if   [ "$pct_r" -ge 80 ]; then seg "$I_CTX" "$ERR_BG"  "$ctx"
    elif [ "$pct_r" -ge 60 ]; then seg "$I_CTX" "$WARN_BG" "$ctx"
    else                           seg "$I_CTX" "$CTX_BG"  "$ctx"; fi
fi
seg "$I_USD" "$COST_BG" "$cost_txt"

# ---- render: rounded caps on the default bg (keeps window transparency) -----
E=$'\e'
rgb() { printf '%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
out="${E}[0m${E}[38;2;$(rgb "${bases[0]}")m${CAP_L}"
for i in "${!txts[@]}"; do
    [ "$i" -gt 0 ] && out+="${E}[0m${E}[38;2;$(rgb "${bases[i-1]}");48;2;$(rgb "${bases[i]}")m${SEP}"
    out+="${E}[38;2;$(rgb "$TEXT");48;2;$(rgb "${bases[i]}");1m ${icons[i]} ${txts[i]} "
done
out+="${E}[0m${E}[38;2;$(rgb "${bases[-1]}")m${CAP_R}${E}[0m"
printf '%s' "$out"
