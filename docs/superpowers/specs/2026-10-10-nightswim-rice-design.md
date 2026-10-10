# Nightswim — Terminal Rice Design

**Date:** 2026-10-10
**Machine:** Ubuntu 24.04, GNOME 46 (X11), Forge tiling, bash, Alacritty 0.17 (snap)
**Inspiration:** [JoshuaHM-p4/dotfiles-fedora](https://github.com/JoshuaHM-p4/dotfiles-fedora) — transparent Alacritty over a desktop wallpaper, plain PS1, pill-style tmux, boxed fastfetch, cava.

## Goal

A fully hand-built terminal look derived from `bg-term.png` (night pool painting: navy water, lilac deck, teal foliage, gold reflections). No starship, no theme plugins — every color comes from one palette. Remove visual chrome (GNOME top panel, window title bar).

**Success:** opening a terminal shows the wallpaper through a translucent Alacritty, a two-line Nightswim prompt, a Nightswim tmux bar on top, and fastfetch with custom art — all in the same palette, with no GNOME panel visible until summoned.

## User decisions (from interview)

| Topic | Decision |
|---|---|
| Background | Wallpaper + transparent Alacritty (no in-terminal image) |
| Top bar | GNOME top panel → autohide (Hide Top Bar extension); dock untouched |
| Prompt | Minimal two-line, pure bash, starship removed |
| tmux | Hand-written pill theme, status on top, replaces catppuccin plugin |
| Extras | fastfetch, cava, shell tool colors (eza/fzf/bat/delta). **Not** nvim. |
| Repo | `aidantiu/dotfiles` (public, fresh history; omerxx kept as `upstream`) |

## 1. Palette — `nightswim/palette.sh`

Single source of truth, exported as shell vars (`NS_BG`, `NS_FG`, …) and mirrored by hand into TOML/conf files that cannot source shell.

| Role | Hex |
|---|---|
| background | `#0e1328` |
| surface | `#2a2f55` |
| foreground | `#d6cfe8` |
| cursor / accent gold | `#e8a95b` |
| accent lilac | `#9a8cc8` |
| accent pink | `#d79bc9` |

ANSI 16:

| | normal | bright |
|---|---|---|
| black | `#0e1328` | `#3b4170` |
| red | `#c9566b` | `#e07a8c` |
| green | `#5f8a7a` | `#86b3a0` |
| yellow | `#e8a95b` | `#f4c57f` |
| blue | `#5a6fb8` | `#8497d6` |
| magenta | `#b07ab8` | `#d79bc9` |
| cyan | `#5f9bb0` | `#8cc4d4` |
| white | `#bdb3d6` | `#e6e0f2` |

## 2. Desktop

- Copy wallpaper to `nightswim/wallpaper/bg-term.png`.
- `gsettings set org.gnome.desktop.background picture-uri[-dark] file://…`, `picture-options zoom`.
- Install **Hide Top Bar** (`hidetopbar@mathieu.bidon.ca`) from extensions.gnome.org for GNOME 46; enable; settings: hide always (not only intellihide), show on mouse at top edge, show in overview.
- Leave ubuntu-dock and Forge alone.
- Captured as `nightswim/desktop.sh` (idempotent) so it can be replayed on a new machine.

## 3. Alacritty — `alacritty/.config/alacritty/alacritty.toml`

- Replaces broken `alactritty.toml` + missing latte import.
- `window.opacity = 0.82`, `decorations = "None"`, `startup_mode = "Maximized"`, `padding = {x=14,y=14}`, `dynamic_padding = true`.
- Font: `0xProto Nerd Font Mono`, size 11.
- Colors: palette above; cursor gold; selection bg `#2a2f55`.
- Keep Joshua's Shift+Enter binding and URL hint (`xdg-open`).

## 4. Prompt — `bash/prompt.sh`

Sourced from `~/.bashrc`; starship `eval` lines in `.bashrc` and `zshrc` commented out (not deleted).

Layout:
```
 ~/dotfiles  master ●  (.venv)  4s
❯
```
- Built in a `PROMPT_COMMAND` function; true-color escapes wrapped in `\[ \]`.
- Path: `\w` in lilac with `` icon.
- Git: `__git_ps1` from `/usr/lib/git-core/git-sh-prompt`, branch in pink with ``; `●` gold if `git status --porcelain` non-empty (skipped outside repos).
- Venv: `($(basename $VIRTUAL_ENV))` in green when set; `VIRTUAL_ENV_DISABLE_PROMPT=1`.
- Duration: shown in dim text when last command ≥ 3s (DEBUG trap timestamp).
- `❯` gold on exit 0, red on non-zero.
- Blank line before every prompt except the first one in a shell.

## 5. tmux — `tmux/nightswim.conf`

- `tmux/tmux.conf` is now the user's live config (prefix `^S`, `bash -l`), symlinked to `~/.tmux.conf`. Catppuccin plugin + its options are removed and `source-file ~/dotfiles/tmux/nightswim.conf` is added. Other plugins and keybinds are kept.
- Copy-mode `wl-copy` → `xclip -in -selection clipboard` (session is X11); install `xclip` if missing.
- `status-position top`, `status-style bg=default`, `status-justify left`.
- Left: `` session `` in lilac pill (fg `#0e1328`).
- Windows: inactive `#I #W` in dim lilac text; current window in gold pill.
- Right: `%H:%M` in surface pill.
- Pane borders `#2a2f55`, active `#9a8cc8`; message/mode styles from palette.

## 6. Extras

**Install:** `sudo apt install cava fzf bat eza git-delta` (verify each exists in 24.04 repos; fall back to GitHub `.deb` for any missing). fastfetch via `ppa:zhangsongcui3371/fastfetch`. `bat` installs as `batcat` → alias `bat=batcat`.

- **fastfetch** — `fastfetch/.config/fastfetch/config.jsonc` + `nightswim.txt` (crescent moon over waves, gold/lilac). Boxed "Software" / "Hardware" sections (Joshua's layout). Auto-run in `.bashrc` only when interactive and `$TMUX` is unset.
- **cava** — `cava/.config/cava/config`: gradient `#3b4170 → #9a8cc8 → #d79bc9 → #e8a95b`, transparent bg, bar width 2, spacing 1.
- **eza / ls** — `ls`/`ll`/`la`/`l` stay GNU ls (no breaking flag changes, e.g. `ls -lt`), themed via `LS_COLORS` overrides (dirs lilac, exec gold, symlinks cyan). eza only as new aliases `lx` (long + git) and `lt` (tree), with `EZA_COLORS`.
- **fzf** — `FZF_DEFAULT_OPTS` with `--color` from palette, rounded border, `❯` pointer.
- **bat + delta** — `nightswim/Nightswim.tmTheme` installed to `~/.config/bat/themes`, `batcat cache --build`; `BAT_THEME=Nightswim`. `.gitconfig` gets `core.pager=delta`, `delta.syntax-theme=Nightswim`, side-by-side off, navigate on.
- Shell env lives in `bash/nightswim-env.sh`, sourced from `.bashrc`.

## 7. Repo layout & linking

```
dotfiles/
  nightswim/   palette.sh, desktop.sh, wallpaper/bg-term.png, Nightswim.tmTheme
  alacritty/.config/alacritty/alacritty.toml
  bash/        prompt.sh, nightswim-env.sh
  fastfetch/.config/fastfetch/{config.jsonc,nightswim.txt}
  cava/.config/cava/config
  tmux/        tmux.conf, nightswim.conf (existing dir)
```
- Existing repo convention is per-tool dirs linked manually / `stow .`. Linking is done by an idempotent `nightswim/install.sh` that creates explicit symlinks (`ln -sfn`), since `stow .` from repo root would link macOS-only dirs too.
- **Done already (pre-rice):** `.bashrc`, `.profile`, `.bash_profile`, `~/bashconfigs`, `.zshrc`, `.zprofile`, `.tmux.conf`, `.gitconfig`, `~/.config/git`, `~/.config/nvim` live in the repo and are symlinked by `install-linux.sh`. Secrets moved to untracked `~/.secrets.sh`.
- Rice changes edit the repo files directly (`bash/.bashrc` gets `source` lines for `prompt.sh` / `nightswim-env.sh`); new links (alacritty, bat, fastfetch, cava) are added to `install-linux.sh`.
- Before changing behavior, back up to `~/.rice-backup-2026-10-10/`.

## Error handling / rollback

- Every replaced file has a backup in `~/.rice-backup-2026-10-10/`.
- Starship lines commented, not removed — rollback = uncomment.
- Prompt functions guard missing deps (`__git_ps1` absent → no git segment; `eza` absent → no alias).
- Hide Top Bar can be disabled with `gnome-extensions disable hidetopbar@mathieu.bidon.ca`.

## Verification

- `bash -n` on all shell files; `alacritty msg config` / launch with no warnings (`alacritty -vv` log clean).
- `tmux source` in a scratch session: no errors; `tmux show -g status-style`.
- `fastfetch --config …` renders; `cava` starts (manual).
- `gnome-screenshot` of a fresh maximized terminal running tmux + fastfetch, reviewed against the wallpaper for contrast; tweak opacity/colors once.

## Out of scope

nvim theming; Ubuntu dock; Ghostty/WezTerm configs in repo; zsh/nushell prompts (starship only commented in zshrc).
