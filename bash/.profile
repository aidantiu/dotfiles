
# workmux-created panes (pane_start_command has wm_ready_*): skip Kiro pty wrapper, which swallows the agent command workmux types
[[ -z ${_WM_PANE+x} ]] && { _WM_PANE=0; [[ -n $TMUX_PANE ]] && [[ $(tmux display -p -t "$TMUX_PANE" "#{pane_start_command}" 2>/dev/null) == *wm_ready_* ]] && _WM_PANE=1; }
# Kiro CLI pre block. Keep at the top of this file.
[[ $_WM_PANE != 1 ]] && [[ -f "${HOME}/.local/share/kiro-cli/shell/profile.pre.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/profile.pre.bash"

# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH


# Added by Antigravity CLI installer
export PATH="/home/hiraya/.local/bin:$PATH"


# Kiro CLI post block. Keep at the bottom of this file.
[[ $_WM_PANE != 1 ]] && [[ -f "${HOME}/.local/share/kiro-cli/shell/profile.post.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/profile.post.bash"
