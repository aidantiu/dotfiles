# Nightswim colors for CLI tools + fastfetch greeting. Sourced from ~/.bashrc.
. "$HOME/dotfiles/nightswim/palette.sh"

# fzf (also used by tmux-fzf / sessionx / fzf-url)
export FZF_DEFAULT_OPTS="--color=bg+:#2a2f55,bg:-1,fg:#bdb3d6,fg+:#e6e0f2,hl:#d79bc9,hl+:#d79bc9,info:#6b6f9a,prompt:#9a8cc8,pointer:#e8a95b,marker:#e8a95b,spinner:#e8a95b,header:#9a8cc8,border:#3b4170 --pointer=❯ --marker=●"

# GNU ls keeps working as before; only colors change. Base saved once so
# re-sourcing doesn't keep appending.
_NS_LS_BASE=${_NS_LS_BASE-$LS_COLORS}
export LS_COLORS="${_NS_LS_BASE}:di=1;38;2;154;140;200:ln=38;2;140;196;212:ex=1;38;2;232;169;91:*.md=38;2;215;155;201"

# eza: new aliases only (ls/ll/la/l unchanged)
if command -v eza >/dev/null; then
  export EZA_COLORS="da=38;2;107;111;154:sn=38;2;232;169;91:sb=38;2;107;111;154:uu=38;2;154;140;200:gm=38;2;232;169;91:ga=38;2;134;179;160:gd=38;2;201;86;107"
  alias lx='eza -la --icons --git --group-directories-first'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
fi

# bat (Ubuntu ships it as batcat)
export BAT_THEME=Nightswim
command -v bat >/dev/null || { command -v batcat >/dev/null && alias bat=batcat; }

# cava 0.7 refuses hex colors when TERM lacks can_change_color (tmux-256color does);
# its noncurses output just needs true color, which tmux passes through.
command -v cava >/dev/null && alias cava='TERM=xterm-256color cava'

# fastfetch: only in a fresh Alacritty shell, not in tmux panes or other terminals
if [ -z "${_ns_fetched:-}" ] && [ -z "${TMUX:-}" ] && [ -n "${ALACRITTY_WINDOW_ID:-}" ] && command -v fastfetch >/dev/null; then
  _ns_fetched=1
  fastfetch
fi
