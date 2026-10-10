
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bash_profile.pre.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bash_profile.pre.bash"

export PATH="/home/hiraya/Documents/flutter/bin:$PATH"

# Source bashrc for login shells
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi



# Added by Antigravity CLI installer
export PATH="/home/hiraya/.local/bin:$PATH"


# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bash_profile.post.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bash_profile.post.bash"
