# Dotfiles symlinked on my machine

### Install with stow:
```bash
stow .
```

## Linux (Ubuntu) — Nightswim

    git clone git@github.com:aidantiu/dotfiles.git ~/dotfiles
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    sudo apt install -y fastfetch eza git-delta cava fzf bat xclip
    ~/dotfiles/install-linux.sh      # symlink configs (backs up existing files)
    ~/dotfiles/nightswim/desktop.sh  # wallpaper
    # put API keys in ~/.secrets.sh (never committed)

Tests: `bash tests/nightswim/run_all.sh`
