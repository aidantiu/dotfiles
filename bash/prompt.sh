# Nightswim prompt — pure bash, replaces starship. Sourced from ~/.bashrc.
#   <folder> ~/dotfiles  <branch> main ●  <py> (.venv)  <clock> 4s
#   ❯
# Safe to re-source (srcb). Git/venv text is referenced via variables in PS1,
# so branch names like $(cmd) are displayed, never executed.

. "$HOME/dotfiles/nightswim/palette.sh"
[ -r /usr/lib/git-core/git-sh-prompt ] && . /usr/lib/git-core/git-sh-prompt

_ns_fg() { printf '\\[\\e[38;2;%d;%d;%dm\\]' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
_NS_LILAC=$(_ns_fg "$NS_LILAC") _NS_PINK=$(_ns_fg "$NS_PINK") _NS_GOLD=$(_ns_fg "$NS_GOLD")
_NS_RED=$(_ns_fg "$NS_RED") _NS_GREEN=$(_ns_fg "$NS_GREEN") _NS_DIM=$(_ns_fg "$NS_DIM")
_NS_RESET='\[\e[0m\]'
# Nerd Font glyphs: folder-open, branch, python, clock
_NS_I_DIR=$'' _NS_I_GIT=$'' _NS_I_PY=$'' _NS_I_TIME=$''

export VIRTUAL_ENV_DISABLE_PROMPT=1
PROMPT_DIRTRIM=4
_ns_first=${_ns_first-1}

# Record command start time; arithmetic in PS0 runs in the current shell.
PS0='${_ns_noop:0:$((_ns_t0=SECONDS,0))}'

_ns_prompt() {
  local status=$? nl='' arrow
  _ns_git='' _ns_dirty='' _ns_venv='' _ns_dur=''

  if declare -F __git_ps1 >/dev/null; then
    _ns_git=$(__git_ps1 '%s')
    if [ -n "$_ns_git" ] && [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null | head -n1)" ]; then
      _ns_dirty=1
    fi
  fi
  [ -n "${VIRTUAL_ENV:-}" ] && _ns_venv="(${VIRTUAL_ENV##*/})"
  if [ -n "${_ns_t0:-}" ]; then
    local d=$((SECONDS - _ns_t0))
    if ((d >= 60)); then _ns_dur="$((d / 60))m$((d % 60))s"; elif ((d >= 3)); then _ns_dur="${d}s"; fi
    unset _ns_t0
  fi

  if [ -n "$_ns_first" ]; then _ns_first=''; else nl='\n'; fi
  if ((status == 0)); then arrow=$_NS_GOLD; else arrow=$_NS_RED; fi

  PS1="\[\e]0;\w\a\]${nl}${_NS_LILAC}${_NS_I_DIR} \w"
  [ -n "$_ns_git" ] && PS1+="  ${_NS_PINK}${_NS_I_GIT} \${_ns_git}"
  [ -n "$_ns_dirty" ] && PS1+=" ${_NS_GOLD}●"
  [ -n "$_ns_venv" ] && PS1+="  ${_NS_GREEN}${_NS_I_PY} \${_ns_venv}"
  [ -n "$_ns_dur" ] && PS1+="  ${_NS_DIM}${_NS_I_TIME} \${_ns_dur}"
  PS1+="${_NS_RESET}\n${arrow}❯${_NS_RESET} "
  return $status
}

# Register once. bash-preexec (Kiro) rewrites PROMPT_COMMAND with newlines,
# so match the bare name rather than ;-delimited entries.
[[ ${PROMPT_COMMAND:-} == *_ns_prompt* ]] || PROMPT_COMMAND="_ns_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
