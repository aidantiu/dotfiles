
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/zshrc.pre.zsh"

eval "$(starship init zsh)"


autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/bin/terraform terraform


# Added by Antigravity CLI installer
export PATH="/home/hiraya/.local/bin:$PATH"


# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/zshrc.post.zsh"
