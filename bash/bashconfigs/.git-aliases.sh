#
# For GIT Day-to-day commands
#
alias ga="git add"
alias gcm="git commit -m"

# Define functions for bash
gl() { git pull "$@"; }
gp() { git push "$@"; }
gdf() { git diff -- "$@"; }

#
# Branches
#
alias gco="git checkout"

#
# Statuses
#
alias glg="git log"
alias glg1="git log --oneline"
alias gs="git status"
alias gref="git reflog"

#
# Restore and Stash
#
alias gst="git stash"
alias gres="git restore"

#
# Merge Branches
#
alias gm="git merge"
alias gms="git merge --squash"

# ------------------------------
# GIT ALIASES HELP FUNCTION
# ------------------------------
git_aliases_help() {
  cat <<'EOF'
DAY-TO-DAY COMMANDS:
    ga     -> git add
    gcm    -> git commit -m
    gp     -> git push origin <branch>
    gl     -> git pull origin <branch>
    gdf    -> git diff <file>

BRANCH SPECIFIC:
    gco    -> git checkout

STATUSES & LOGS:
    gs     -> git status
    glg    -> git log
    glg1   -> git log --oneline
    gref   -> git reflog

RESTORE & REVERT:
    gst    -> git stash
    gres   -> git restore

MERGE BRANCHES
    gm 	   -> git merge
 
EOF
}

# Custom completion function for gl and gp
_gl_gp_completion() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # If previous word is "origin", complete with branch names
  if [[ "$prev" == "origin" ]]; then
    local branches=$(git branch -a 2>/dev/null | grep -v HEAD | sed 's/^[* ]*//' | sed 's/remotes\/origin\///' | sort -u)
    COMPREPLY=($(compgen -W "$branches" -- "$cur"))
    return 0
  fi

  # Otherwise, suggest "origin"
  COMPREPLY=($(compgen -W "origin" -- "$cur"))
}

# Enable bash completion if available
if type __git_complete &>/dev/null; then
  __git_complete ga _git_add
  __git_complete gcm _git_commit
  __git_complete gco _git_checkout
  __git_complete gs _git_status
  __git_complete glg _git_log
  __git_complete glg1 _git_log
  __git_complete gref _git_reflog
  __git_complete gst _git_stash
  __git_complete gres _git_restore
  __git_complete gdf _git_diff
  __git_complete gm _git_merge

  # Use custom completion for gl and gp
  complete -F _gl_gp_completion gl gp
fi
