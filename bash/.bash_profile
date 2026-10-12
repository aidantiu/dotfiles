
# workmux-created panes (pane_start_command has wm_ready_*): skip Kiro pty wrapper, which swallows the agent command workmux types
[[ -z ${_WM_PANE+x} ]] && { _WM_PANE=0; [[ -n $TMUX_PANE ]] && [[ $(tmux display -p -t "$TMUX_PANE" "#{pane_start_command}" 2>/dev/null) == *wm_ready_* ]] && _WM_PANE=1; }
# Kiro CLI pre block. Keep at the top of this file.
[[ $_WM_PANE != 1 ]] && [[ -f "${HOME}/.local/share/kiro-cli/shell/bash_profile.pre.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bash_profile.pre.bash"

export PATH="/home/hiraya/Documents/flutter/bin:$PATH"

# Source bashrc for login shells
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi



# Added by Antigravity CLI installer
export PATH="/home/hiraya/.local/bin:$PATH"


# Kiro CLI post block. Keep at the bottom of this file.
[[ $_WM_PANE != 1 ]] && [[ -f "${HOME}/.local/share/kiro-cli/shell/bash_profile.post.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bash_profile.post.bash"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"   # rustup; absent on machines without Rust
