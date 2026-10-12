# Dotfiles symlinked on my machine

### Install with stow:
```bash
stow .
```

## Linux (Ubuntu) — Nightswim

    git clone https://github.com/aidantiu/dotfiles.git ~/dotfiles
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    sudo apt install -y fastfetch eza git-delta cava fzf bat xclip
    # Nerd Font used by Alacritty (icons in prompt, tmux, fastfetch)
    mkdir -p ~/.local/share/fonts && cd /tmp && \
      curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip && \
      unzip -o 0xProto.zip -d ~/.local/share/fonts '*.ttf' && fc-cache -f && cd -
    ~/dotfiles/install-linux.sh      # symlink configs (backs up existing files)
    ~/dotfiles/nightswim/desktop.sh  # wallpaper
    # put API keys in ~/.secrets.sh (never committed)

Window keys (the terminal has no title bar): Super+↑ maximize, Super+↓ restore,
Super+, minimize (`gsettings set org.gnome.desktop.wm.keybindings minimize "['<Super>comma']"`).
New Alacritty windows are maximized by the `nightswim-automax` user service.
`dot` or `dot --help` prints the live shortcut cheat sheet.

### Per-machine overrides — `hosts/<hostname>/`

Shared configs stay the same on every laptop; anything machine-specific lives in
`hosts/$(hostname -s)/` and is picked up automatically when that folder exists:

    hosts/<host>/install.sh   sourced at the end of install-linux.sh (can use `link`)
    hosts/<host>/desktop.sh   sourced at the end of nightswim/desktop.sh (can use `xs`, `custom_key`)
    hosts/<host>/conky.lua    loaded at the end of conky.conf (edit `conky.config`)

`hosts/ymnwricmp/` is the ThinkPad X1 Carbon 4th gen (Wayland, HD 520): lighter blur,
Vicinae on Alt+Space, centred windows, 1.25× text, conky pinned to the laptop panel.

### GNOME desktop rice — snapshots & recovery

    ~/dotfiles/nightswim/gnome/install.sh   # fetch extensions/themes/icons/fonts (no sudo)
    ~/dotfiles/nightswim/desktop.sh         # apply; snapshots the current desktop first
    ~/dotfiles/nightswim/gnome/snapshot.sh list
    ~/dotfiles/nightswim/gnome/snapshot.sh save <label>
    ~/dotfiles/nightswim/gnome/snapshot.sh restore <name>   # then log out/in

Snapshots live in `~/.nightswim-backups/` (full `dconf dump` + rice config files).
Black screen after login: Ctrl+Alt+F3, log in, run `snapshot.sh restore <name>`,
then `sudo systemctl restart gdm3`.

Tests: `bash tests/nightswim/run_all.sh`

## Agents — oh-my-pi + workmux

    wm add <branch> -p "task"     # worktree + tmux window running the default agent (omp)
    wm add <branch> -a claude     # pick another detected agent (claude, codex, cursor)
    prefix + w                    # workmux dashboard
    wm-agents                     # re-detect agents after installing/removing one

Premium models (Fable, GPT-6 Astra, each provider's top tier) ask once per session in omp.
Edit `omp/model-guard.yml` to change what's restricted.
Tests: `node --test tests/omp/policy.test.ts` and `bash tests/nightswim/run_all.sh`.
