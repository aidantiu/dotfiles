# Nightswim Terminal Rice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Theme Alacritty, bash prompt, tmux, fastfetch, cava and CLI tools with the "Nightswim" palette taken from `bg-term.png`, and autohide the GNOME top panel — without breaking the user's existing bash/tmux behavior.

**Architecture:** All config lives in `~/dotfiles` (repo `aidantiu/dotfiles`) and is symlinked into `$HOME` by `install-linux.sh`. One palette (`nightswim/palette.sh`) is sourced by shell code and mirrored by hand into TOML/conf/JSON. Each tool gets one focused file; shell tests live in `tests/nightswim/` and are plain bash scripts that exit non-zero on failure.

**Tech Stack:** bash 5.2, tmux 3.4, Alacritty 0.17 (snap), fastfetch (PPA), cava 0.7.4, eza 0.18, fzf 0.44, bat 0.24 (`batcat`), git-delta 0.16, GNOME 46 X11 + Hide Top Bar extension.

**Spec:** `docs/superpowers/specs/2026-10-10-nightswim-rice-design.md`

## Global Constraints

- Palette hexes are exactly: bg `#0e1328`, surface `#2a2f55`, fg `#d6cfe8`, dim `#6b6f9a`, gold `#e8a95b`, lilac `#9a8cc8`, pink `#d79bc9`; ANSI normal `#0e1328 #c9566b #5f8a7a #e8a95b #5a6fb8 #b07ab8 #5f9bb0 #bdb3d6`, bright `#3b4170 #e07a8c #86b3a0 #f4c57f #8497d6 #d79bc9 #8cc4d4 #e6e0f2`.
- **No breaking changes to the user's bash and tmux.** Every existing alias, function, PATH entry and env var stays identical except the ones this plan intentionally adds or changes (listed in Task 8). tmux prefix stays `C-s`; all keybindings except the copy-mode `y` pipe stay identical.
- `ls`, `ll`, `la`, `l` keep using GNU `ls` (themed only via `LS_COLORS`). eza is exposed only as the new aliases `lt` and `lx`. *(Deviation from spec §6: aliasing `ls` to eza breaks flags like `ls -lt`.)*
- tmux theme is sourced from `~/dotfiles/tmux/nightswim.conf` directly (no `~/.config/tmux` link). *(Simplifies spec §5.)*
- Secrets stay in untracked `~/.secrets.sh`; never commit keys. Repo is public.
- Font: `0xProto Nerd Font Mono`. Alacritty opacity `0.82`.
- `sudo` needs a password: package installs are run by the user via `! <command>`.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Re-sourcing `.bashrc` (`srcb`)** must not duplicate `PROMPT_COMMAND` entries or re-run fastfetch. → test in Task 3 and Task 4.
2. **Git branch names containing `$(...)`** must be shown, not executed, by the prompt. → test in Task 3.
3. **Shells inside tmux / non-Alacritty terminals (VS Code, Claude Code)** must not print fastfetch. → test in Task 4.
4. **Machines without delta/eza/batcat** (fresh clone before installing packages) must still have working `git log`/`git diff` and no shell errors. → tests in Task 4.
5. **Exit status** shown by the prompt must be the user's last command, not something the prompt ran. → test in Task 3.

## File Map

| File | Responsibility |
|---|---|
| `nightswim/palette.sh` | Color source of truth (shell vars) |
| `nightswim/wallpaper/bg-term.png` | Wallpaper |
| `nightswim/desktop.sh` | Set wallpaper, install/enable/configure Hide Top Bar |
| `alacritty/alacritty.toml` | Terminal look (linked as `~/.config/alacritty`) |
| `bash/prompt.sh` | Two-line PS1 |
| `bash/nightswim-env.sh` | fzf/LS_COLORS/eza/bat env + fastfetch autorun |
| `bat/themes/Nightswim.tmTheme` | Syntax theme for bat + delta (linked as `~/.config/bat`) |
| `git/.gitconfig` | + delta pager (guarded) |
| `tmux/nightswim.conf` | tmux status/pane colors |
| `tmux/tmux.conf` | − catppuccin, + source nightswim, xclip |
| `fastfetch/config.jsonc`, `fastfetch/nightswim.txt` | Fetch layout + logo (linked as `~/.config/fastfetch`) |
| `cava/config` | Visualizer colors (linked as `~/.config/cava`) |
| `install-linux.sh` | + links for alacritty, bat, fastfetch, cava |
| `tests/nightswim/*.sh` | One test script per component |

---

### Task 0: Install packages (user runs)

- [ ] **Step 1: Ask the user to run**

```
! sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch && sudo apt update && sudo apt install -y fastfetch eza git-delta cava fzf bat xclip
```

- [ ] **Step 2: Verify**

Run: `for t in fastfetch eza delta cava fzf batcat xclip; do command -v $t >/dev/null && echo "ok $t" || echo "MISSING $t"; done`
Expected: seven `ok` lines.

- [ ] **Step 3: Baseline snapshot** — create `tests/nightswim/snapshot.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# Snapshot interactive+login bash (aliases, functions, PATH, env with hashed values)
# and tmux options/keys. Usage: snapshot.sh <out-prefix>
out=$1
for mode in ic lic; do
  bash -$mode 'alias; echo "##FUNCS"; declare -F; echo "##PATH"; echo "$PATH"; echo "##ENV"
    env -0 | sort -z | while IFS= read -r -d "" kv; do k=${kv%%=*}
      case $k in SHLVL|_|OLDPWD|PWD|SHELL_PID|STARSHIP_SESSION_KEY|BASH_EXECUTION_STRING) continue;; esac
      printf "%s=%s\n" "$k" "$(printf %s "${kv#*=}" | sha1sum | cut -c1-12)"; done' </dev/null 2>/dev/null > "$out.$mode"
done
tmux -L snap -f ~/.tmux.conf new-session -d -s s 2>/dev/null; sleep 2
tmux -L snap show -g 2>/dev/null | sort > "$out.tmux"
tmux -L snap list-keys 2>/dev/null | sort > "$out.tmuxkeys"
tmux -L snap kill-server 2>/dev/null
```

Run: `bash tests/nightswim/snapshot.sh ~/.cache/ns-before` (taken before any config change; Task 8 diffs against it).

---

### Task 1: Palette, wallpaper, Hide Top Bar

**Files:**
- Create: `nightswim/palette.sh`, `nightswim/desktop.sh`, `nightswim/wallpaper/bg-term.png`
- Test: `tests/nightswim/test_desktop.sh`

**Interfaces:**
- Produces: shell vars `NS_BG NS_SURFACE NS_FG NS_DIM NS_GOLD NS_LILAC NS_PINK NS_RED NS_GREEN NS_CYAN NS_BLUE` (6 hex digits, no `#`), used by Tasks 3–4.

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_desktop.sh`

```bash
#!/usr/bin/env bash
# Desktop checks: palette loads, wallpaper set, Hide Top Bar enabled + configured.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

. "$DOT/nightswim/palette.sh"
check "palette gold" '[ "$NS_GOLD" = e8a95b ]'
check "palette bg" '[ "$NS_BG" = 0e1328 ]'

WALL="file://$DOT/nightswim/wallpaper/bg-term.png"
check "wallpaper light" '[ "$(gsettings get org.gnome.desktop.background picture-uri)" = "'"'$WALL'"'" ]'
check "wallpaper dark"  '[ "$(gsettings get org.gnome.desktop.background picture-uri-dark)" = "'"'$WALL'"'" ]'

UUID=hidetopbar@mathieu.bidon.ca
EXT="$HOME/.local/share/gnome-shell/extensions/$UUID"
check "hidetopbar enabled" 'gnome-extensions info "$UUID" 2>/dev/null | grep -q "State: ACTIVE\|State: ENABLED"'
hs() { gsettings --schemadir "$EXT/schemas" get org.gnome.shell.extensions.hidetopbar "$1" 2>/dev/null; }
check "always hide (no intellihide)" '[ "$(hs enable-intellihide)" = false ]'
check "reveal on mouse" '[ "$(hs mouse-sensitive)" = true ]'
check "show in overview" '[ "$(hs show-in-overview)" = true ]'
exit $fail
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/nightswim/test_desktop.sh`
Expected: FAIL (palette.sh missing).

- [ ] **Step 3: Implement** — `nightswim/palette.sh`

```bash
# Nightswim palette — sampled from nightswim/wallpaper/bg-term.png.
# Shell-sourceable. TOML/conf/JSON files mirror these values by hand.
NS_BG=0e1328       # deep pool water
NS_SURFACE=2a2f55  # pool shadow
NS_FG=d6cfe8       # lavender deck in light
NS_DIM=6b6f9a      # muted text
NS_GOLD=e8a95b     # gold reflections (primary accent)
NS_LILAC=9a8cc8    # lilac deck
NS_PINK=d79bc9     # umbrella
NS_RED=c9566b      # red flowers
NS_GREEN=86b3a0    # foliage
NS_CYAN=8cc4d4
NS_BLUE=8497d6
```

`nightswim/desktop.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# Nightswim desktop: wallpaper + Hide Top Bar (GNOME 46). Safe to re-run.
set -euo pipefail
DOT="$(cd "$(dirname "$0")/.." && pwd)"
WALL="file://$DOT/nightswim/wallpaper/bg-term.png"

gsettings set org.gnome.desktop.background picture-uri "$WALL"
gsettings set org.gnome.desktop.background picture-uri-dark "$WALL"
gsettings set org.gnome.desktop.background picture-options zoom

UUID=hidetopbar@mathieu.bidon.ca
EXT="$HOME/.local/share/gnome-shell/extensions/$UUID"
if [ ! -d "$EXT" ]; then
  echo "Installing Hide Top Bar — click Install in the GNOME dialog"
  gdbus call --session --timeout 120 --dest org.gnome.Shell.Extensions \
    --object-path /org/gnome/Shell/Extensions \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "$UUID" >/dev/null
fi
gnome-extensions enable "$UUID"

hs() { gsettings --schemadir "$EXT/schemas" set org.gnome.shell.extensions.hidetopbar "$@"; }
hs enable-intellihide false   # always hidden, not only when a window overlaps
hs mouse-sensitive true       # push mouse to top edge to reveal
hs show-in-overview true      # Super shows it
```

- [ ] **Step 4: Copy wallpaper and run**

```bash
mkdir -p nightswim/wallpaper && cp ~/Downloads/bg-term.png nightswim/wallpaper/
gsettings --schemadir ~/.local/share/gnome-shell/extensions/hidetopbar@mathieu.bidon.ca/schemas list-keys org.gnome.shell.extensions.hidetopbar 2>/dev/null  # (after install) confirm the three keys exist
./nightswim/desktop.sh
```
User clicks **Install** in the GNOME dialog.

- [ ] **Step 5: Run test** — `bash tests/nightswim/test_desktop.sh` → all `ok`.

- [ ] **Step 6: Commit**

```bash
git add nightswim tests/nightswim/test_desktop.sh
git commit -m "nightswim: palette, wallpaper, hide top bar"
```

---

### Task 2: Alacritty

**Files:**
- Create: `alacritty/alacritty.toml`
- Modify: `install-linux.sh` (add link)
- Test: `tests/nightswim/test_alacritty.sh`

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_alacritty.sh`

```bash
#!/usr/bin/env bash
# Alacritty config parses, has Nightswim values, and loads without warnings.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
CFG="$DOT/alacritty/alacritty.toml"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "config exists" '[ -f "$CFG" ]'
check "toml values" 'python3 -I - "$CFG" <<"EOF"
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
w, col = c["window"], c["colors"]
assert w["opacity"] == 0.82 and w["decorations"] == "None"
assert col["primary"]["background"] == "#0e1328"
assert col["cursor"]["cursor"] == "#e8a95b"
assert col["normal"]["yellow"] == "#e8a95b" and col["bright"]["black"] == "#3b4170"
assert c["font"]["normal"]["family"] == "0xProto Nerd Font Mono"
EOF'
log=$(timeout 10 alacritty -vv --config-file "$CFG" -e true 2>&1)
check "no config errors/warnings" '! grep -qE "ERROR|WARN.*(config|Unused)" <<<"$log"'
check "linked into ~/.config" '[ "$(readlink -f ~/.config/alacritty/alacritty.toml)" = "$CFG" ]'
exit $fail
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/nightswim/test_alacritty.sh` → FAIL config exists.

- [ ] **Step 3: Implement** — `alacritty/alacritty.toml`

```toml
# Nightswim — palette in ~/dotfiles/nightswim/palette.sh
[general]
live_config_reload = true

[window]
opacity = 0.82
decorations = "None"
startup_mode = "Maximized"
padding = { x = 14, y = 14 }
dynamic_padding = true

[font]
normal = { family = "0xProto Nerd Font Mono", style = "Regular" }
size = 11.0

[scrolling]
history = 50000

[cursor]
style = { shape = "Block", blinking = "Off" }

[colors.primary]
background = "#0e1328"
foreground = "#d6cfe8"

[colors.cursor]
text = "#0e1328"
cursor = "#e8a95b"

[colors.selection]
text = "CellForeground"
background = "#2a2f55"

[colors.normal]
black = "#0e1328"
red = "#c9566b"
green = "#5f8a7a"
yellow = "#e8a95b"
blue = "#5a6fb8"
magenta = "#b07ab8"
cyan = "#5f9bb0"
white = "#bdb3d6"

[colors.bright]
black = "#3b4170"
red = "#e07a8c"
green = "#86b3a0"
yellow = "#f4c57f"
blue = "#8497d6"
magenta = "#d79bc9"
cyan = "#8cc4d4"
white = "#e6e0f2"

# Ctrl+Shift+O: open URLs with xdg-open
[[hints.enabled]]
command = "xdg-open"
hyperlinks = true
post_processing = true
binding = { key = "O", mods = "Control|Shift" }

# Shift+Enter sends ESC+CR (newline in Claude Code and similar TUIs)
[[keyboard.bindings]]
key = "Return"
mods = "Shift"
chars = "\u001B\r"
```

Add to `install-linux.sh` after the nvim link:

```bash
# alacritty
link alacritty           "$HOME/.config/alacritty"
```

- [ ] **Step 4: Link and test**

Run: `./install-linux.sh && bash tests/nightswim/test_alacritty.sh` → all `ok`. (Old broken `alactritty.toml` + catppuccin file land in the backup dir.)

- [ ] **Step 5: Commit**

```bash
git add alacritty install-linux.sh tests/nightswim/test_alacritty.sh
git commit -m "alacritty: nightswim colors, transparent, no decorations"
```

---

### Task 3: Bash prompt (replaces starship)

**Files:**
- Create: `bash/prompt.sh`
- Modify: `bash/.bashrc` (the `eval "$(starship init bash)"` line under `# For git`)
- Test: `tests/nightswim/test_prompt.sh`

**Interfaces:**
- Consumes: `nightswim/palette.sh` vars.
- Produces: function `_ns_prompt` (first entry of `PROMPT_COMMAND`), `PS0` start-time hook setting `_ns_t0`, vars `_ns_git _ns_dirty _ns_venv _ns_dur` referenced by `PS1`.

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_prompt.sh`

```bash
#!/usr/bin/env bash
# Tests for bash/prompt.sh. Run: bash tests/nightswim/test_prompt.sh
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
render() { OUT="${PS1@P}"; }
GOLD='38;2;232;169;91m'; RED='38;2;201;86;107m'
TITLE_NL=$'\a\002\n'   # end of title escape followed by a newline = blank line
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
PROMPT_COMMAND=
. "$DOT/bash/prompt.sh"

cd "$tmp"
true; _ns_prompt; render
check "first prompt has no leading blank line" '[[ $OUT != *"$TITLE_NL"* ]]'
check "path shown" '[[ $OUT == *"${tmp##*/}"* ]]'
check "no git segment outside repo" '[[ $OUT != *""* ]]'
check "gold arrow after success" '[[ $OUT == *"$GOLD"*"❯"* ]]'
false; _ns_prompt; render
check "red arrow after failure" '[[ $OUT == *"$RED"*"❯"* ]]'
check "blank line before later prompts" '[[ $OUT == *"$TITLE_NL"* ]]'

git init -q -b main repo && cd repo && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
_ns_prompt; render
check "branch shown" '[[ $OUT == *" main"* ]]'
check "clean repo: no dirty dot" '[[ $OUT != *"●"* ]]'
echo a > f && git add f
_ns_prompt; render
check "dirty dot shown" '[[ $OUT == *"●"* ]]'
git checkout -q -b '$(id>pwned)'   # git forbids spaces in ref names
_ns_prompt; render
check "malicious branch shown, not executed" '[ ! -e pwned ] && [[ $OUT == *"\$(id>pwned)"* ]]'

VIRTUAL_ENV=/x/.venv _ns_prompt; render
check "venv shown" '[[ $OUT == *"(.venv)"* ]]'
_ns_prompt; render
check "venv gone when unset" '[[ $OUT != *"(.venv)"* ]]'

_ns_t0=$((SECONDS-5)); _ns_prompt; render
check "duration shown for 5s command" '[[ $OUT == *" 5s"* ]]'
: "${PS0@P}"; _ns_prompt; render
check "PS0 hook records start; short command hides duration" '[[ $OUT != *""* ]]'

. "$DOT/bash/prompt.sh"
check "re-sourcing does not duplicate PROMPT_COMMAND" '[ "$(grep -o _ns_prompt <<<"$PROMPT_COMMAND" | wc -l)" = 1 ]'
check "_ns_prompt runs first (sees real exit status)" '[[ $PROMPT_COMMAND == _ns_prompt* ]]'
exit $fail
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/nightswim/test_prompt.sh` → FAIL (`prompt.sh` missing / `_ns_prompt: command not found`).

- [ ] **Step 3: Implement** — `bash/prompt.sh`

```bash
# Nightswim prompt — pure bash, replaces starship. Sourced from ~/.bashrc.
#    ~/dotfiles   main ●   (.venv)   4s
#   ❯
# Safe to re-source (srcb). Git/venv text is referenced via variables in PS1,
# so branch names like $(cmd) are displayed, never executed.

. "$HOME/dotfiles/nightswim/palette.sh"
[ -r /usr/lib/git-core/git-sh-prompt ] && . /usr/lib/git-core/git-sh-prompt

_ns_fg() { printf '\\[\\e[38;2;%d;%d;%dm\\]' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
_NS_LILAC=$(_ns_fg "$NS_LILAC") _NS_PINK=$(_ns_fg "$NS_PINK") _NS_GOLD=$(_ns_fg "$NS_GOLD")
_NS_RED=$(_ns_fg "$NS_RED") _NS_GREEN=$(_ns_fg "$NS_GREEN") _NS_DIM=$(_ns_fg "$NS_DIM")
_NS_RESET='\[\e[0m\]'

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

  PS1="\[\e]0;\w\a\]${nl}${_NS_LILAC} \w"
  [ -n "$_ns_git" ] && PS1+="  ${_NS_PINK} \${_ns_git}"
  [ -n "$_ns_dirty" ] && PS1+=" ${_NS_GOLD}●"
  [ -n "$_ns_venv" ] && PS1+="  ${_NS_GREEN} \${_ns_venv}"
  [ -n "$_ns_dur" ] && PS1+="  ${_NS_DIM} \${_ns_dur}"
  PS1+="${_NS_RESET}\n${arrow}❯${_NS_RESET} "
  return $status
}

case ";${PROMPT_COMMAND:-};" in
  *";_ns_prompt;"*) ;;
  *) PROMPT_COMMAND="_ns_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
```

- [ ] **Step 4: Run test** — `bash tests/nightswim/test_prompt.sh` → all `ok`.

- [ ] **Step 5: Wire into `.bashrc`** — replace

```bash
# For git
eval "$(starship init bash)"
```
with
```bash
# Prompt: Nightswim (starship disabled — uncomment to roll back)
# eval "$(starship init bash)"
[ -f ~/dotfiles/bash/prompt.sh ] && . ~/dotfiles/bash/prompt.sh
```
And in `zshrc/.zshrc` comment out `eval "$(starship init zsh)"` the same way (zsh not installed; keeps spec consistent).

- [ ] **Step 6: Smoke test** — `bash -ic 'echo "$PROMPT_COMMAND"; declare -F _ns_prompt' 2>/dev/null` → shows `_ns_prompt`, no `starship` in PROMPT_COMMAND.

- [ ] **Step 7: Commit**

```bash
git add bash/prompt.sh bash/.bashrc zshrc/.zshrc tests/nightswim/test_prompt.sh
git commit -m "bash: nightswim two-line prompt, drop starship"
```

---

### Task 4: CLI tool colors, bat theme, delta, fastfetch autorun

**Files:**
- Create: `bash/nightswim-env.sh`, `bat/themes/Nightswim.tmTheme`
- Modify: `bash/.bashrc` (one source line), `git/.gitconfig`, `install-linux.sh`
- Test: `tests/nightswim/test_env.sh`

**Interfaces:**
- Consumes: palette vars.
- Produces: env `FZF_DEFAULT_OPTS`, `LS_COLORS` (+ overrides), `EZA_COLORS`, `BAT_THEME=Nightswim`; aliases `bat` (→batcat, only if `bat` missing), `lt`, `lx`; function-free fastfetch autorun guarded by `_ns_fetched`.

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_env.sh`

```bash
#!/usr/bin/env bash
# Tool colors + fastfetch autorun guards + delta/bat fallbacks.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ENV="$DOT/bash/nightswim-env.sh"

check "env file exists" '[ -f "$ENV" ]'
o=$(bash -ic ". '$ENV'; echo \"\$FZF_DEFAULT_OPTS|\$BAT_THEME|\$LS_COLORS\"; alias lt lx" 2>/dev/null </dev/null)
check "fzf colors" '[[ $o == *"pointer:#e8a95b"* ]]'
check "bat theme" '[[ $o == *"|Nightswim|"* ]]'
check "ls dirs lilac" '[[ $o == *"di=1;38;2;154;140;200"* ]]'
check "eza aliases" '[[ $o == *"alias lt="* && $o == *"alias lx="* ]]'
check "ls untouched" '[ "$(bash -ic ". '"'$ENV'"'; alias ls" 2>/dev/null </dev/null)" = "alias ls='"'ls --color=auto'"'" ]'

# fastfetch only in a top-level Alacritty shell, once
n=$(env -u TMUX ALACRITTY_WINDOW_ID=1 bash -ic ". '$ENV'; . '$ENV'" 2>/dev/null </dev/null | grep -c "Software")
check "fastfetch runs once in alacritty (re-source safe)" '[ "$n" = 1 ]'
n=$(TMUX=x ALACRITTY_WINDOW_ID=1 bash -ic ". '$ENV'" 2>/dev/null </dev/null | grep -c "Software")
check "no fastfetch inside tmux" '[ "$n" = 0 ]'
n=$(env -u TMUX -u ALACRITTY_WINDOW_ID bash -ic ". '$ENV'" 2>/dev/null </dev/null | grep -c "Software")
check "no fastfetch in other terminals" '[ "$n" = 0 ]'

# missing tools must not error (/bin == /usr/bin on Ubuntu, so build a minimal PATH)
bin=$(mktemp -d); trap 'rm -rf "$bin"' EXIT
for c in bash sh less cat; do ln -s "$(command -v $c)" "$bin/$c"; done
e=$(env -u TMUX ALACRITTY_WINDOW_ID=1 PATH="$bin" bash --norc -ic ". '$ENV'" 2>&1 </dev/null | grep -v "job control\|ioctl")
check "no errors when fastfetch/eza/batcat absent" '[ -z "$e" ]'
d=$(echo pager-ok | PATH="$bin" sh -c "$(git config core.pager)" 2>&1)
check "git pager falls back to less without delta" '[ "$d" = pager-ok ]'
d=$(echo pager-ok | sh -c "$(git config core.pager)" 2>&1)
check "git pager works with delta" '[[ $d == *pager-ok* ]]'
check "delta theme configured" '[ "$(git config delta.syntax-theme)" = Nightswim ]'
check "bat knows Nightswim" 'batcat --list-themes 2>/dev/null | grep -qx Nightswim'
exit $fail
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/nightswim/test_env.sh` → FAIL env file exists.

- [ ] **Step 3: Implement** — `bash/nightswim-env.sh`

```bash
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

# fastfetch: only in a fresh Alacritty shell, not in tmux panes or other terminals
if [ -z "${_ns_fetched:-}" ] && [ -z "${TMUX:-}" ] && [ -n "${ALACRITTY_WINDOW_ID:-}" ] && command -v fastfetch >/dev/null; then
  _ns_fetched=1
  fastfetch
fi
```

Add right after the prompt.sh line in `bash/.bashrc`:

```bash
[ -f ~/dotfiles/bash/nightswim-env.sh ] && . ~/dotfiles/bash/nightswim-env.sh
```

`bat/themes/Nightswim.tmTheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Nightswim — palette in ~/dotfiles/nightswim/palette.sh -->
<plist version="1.0">
<dict>
  <key>name</key><string>Nightswim</string>
  <key>settings</key>
  <array>
    <dict><key>settings</key><dict>
      <key>background</key><string>#0e1328</string>
      <key>foreground</key><string>#d6cfe8</string>
      <key>caret</key><string>#e8a95b</string>
      <key>selection</key><string>#2a2f55</string>
      <key>lineHighlight</key><string>#1a1f3d</string>
      <key>gutterForeground</key><string>#6b6f9a</string>
    </dict></dict>
    <dict><key>scope</key><string>comment, punctuation.definition.comment</string>
      <key>settings</key><dict><key>foreground</key><string>#6b6f9a</string><key>fontStyle</key><string>italic</string></dict></dict>
    <dict><key>scope</key><string>string, markup.inline.raw</string>
      <key>settings</key><dict><key>foreground</key><string>#86b3a0</string></dict></dict>
    <dict><key>scope</key><string>constant.numeric, constant.language, constant.character</string>
      <key>settings</key><dict><key>foreground</key><string>#e8a95b</string></dict></dict>
    <dict><key>scope</key><string>keyword, storage, keyword.operator.word</string>
      <key>settings</key><dict><key>foreground</key><string>#9a8cc8</string></dict></dict>
    <dict><key>scope</key><string>entity.name.function, support.function, meta.function-call</string>
      <key>settings</key><dict><key>foreground</key><string>#8497d6</string></dict></dict>
    <dict><key>scope</key><string>entity.name.type, entity.name.class, support.type, support.class</string>
      <key>settings</key><dict><key>foreground</key><string>#d79bc9</string></dict></dict>
    <dict><key>scope</key><string>variable.parameter, variable.other.member, entity.other.attribute-name</string>
      <key>settings</key><dict><key>foreground</key><string>#8cc4d4</string></dict></dict>
    <dict><key>scope</key><string>entity.name.tag</string>
      <key>settings</key><dict><key>foreground</key><string>#d79bc9</string></dict></dict>
    <dict><key>scope</key><string>invalid</string>
      <key>settings</key><dict><key>foreground</key><string>#c9566b</string></dict></dict>
    <dict><key>scope</key><string>markup.heading, entity.name.section</string>
      <key>settings</key><dict><key>foreground</key><string>#e8a95b</string><key>fontStyle</key><string>bold</string></dict></dict>
    <dict><key>scope</key><string>markup.inserted</string>
      <key>settings</key><dict><key>foreground</key><string>#86b3a0</string></dict></dict>
    <dict><key>scope</key><string>markup.deleted</string>
      <key>settings</key><dict><key>foreground</key><string>#c9566b</string></dict></dict>
    <dict><key>scope</key><string>markup.changed</string>
      <key>settings</key><dict><key>foreground</key><string>#e8a95b</string></dict></dict>
  </array>
</dict>
</plist>
```

Append to `git/.gitconfig` (pager commands fall back if delta is missing):

```ini
[core]
	pager = command -v delta >/dev/null 2>&1 && exec delta || exec less -FRX
[interactive]
	diffFilter = command -v delta >/dev/null 2>&1 && exec delta --color-only || exec cat
[delta]
	navigate = true
	line-numbers = true
	syntax-theme = Nightswim
	minus-style = syntax "#3a1f33"
	plus-style = syntax "#1d3330"
	line-numbers-minus-style = "#c9566b"
	line-numbers-plus-style = "#86b3a0"
	line-numbers-zero-style = "#3b4170"
	hunk-header-style = file line-number syntax
	hunk-header-decoration-style = "#9a8cc8" box
	file-style = "#e8a95b" bold
	file-decoration-style = "#e8a95b" ul
[merge]
	conflictstyle = zdiff3
```

Add to `install-linux.sh`:

```bash
# bat (themes) — rebuild cache after linking
link bat                 "$HOME/.config/bat"
command -v batcat >/dev/null && batcat cache --build >/dev/null
```

- [ ] **Step 4: Link and test** — `./install-linux.sh && bash tests/nightswim/test_env.sh`
Expected: all `ok` except the fastfetch-runs-once check, which needs Task 6's config to print "Software" — re-run after Task 6.

- [ ] **Step 5: Commit**

```bash
git add bash/nightswim-env.sh bash/.bashrc bat git/.gitconfig install-linux.sh tests/nightswim/test_env.sh
git commit -m "nightswim: fzf/ls/eza/bat/delta colors, fastfetch autorun"
```

---

### Task 5: tmux theme

**Files:**
- Create: `tmux/nightswim.conf`
- Modify: `tmux/tmux.conf`
- Test: `tests/nightswim/test_tmux.sh`

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_tmux.sh`

```bash
#!/usr/bin/env bash
# Start an isolated tmux server with the real config and inspect it.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
T="tmux -L nstest"
$T -f "$DOT/tmux/tmux.conf" new-session -d -s t 2>/tmp/nstest.err; sleep 2
g() { $T show -gv "$1" 2>/dev/null; }

check "config loads without errors" '[ ! -s /tmp/nstest.err ]'
check "prefix unchanged (C-s)" '[ "$(g prefix)" = C-s ]'
check "status on top" '[ "$(g status-position)" = top ]'
check "transparent bar" '[[ $(g status-style) == *"bg=default"* ]]'
check "session pill lilac" '[[ $(g status-left) == *"#9a8cc8"*"#S"* ]]'
check "current window gold" '[[ $(g window-status-current-format) == *"#e8a95b"* ]]'
check "active border lilac" '[[ $(g pane-active-border-style) == *"#9a8cc8"* ]]'
check "catppuccin removed" '! $T show -g 2>/dev/null | grep -q "@catppuccin\|catppuccin-tmux"'
check "copy uses xclip" '$T list-keys -T copy-mode-vi y | grep -q xclip'
check "sessionx still bound" '$T show -gv @sessionx-bind | grep -qx o'
$T kill-server 2>/dev/null
exit $fail
```

- [ ] **Step 2: Run to verify it fails** — `bash tests/nightswim/test_tmux.sh` → FAILs on colors/catppuccin/xclip.

- [ ] **Step 3: Implement** — `tmux/nightswim.conf`

```tmux
# Nightswim tmux theme — palette in ~/dotfiles/nightswim/palette.sh
# Pills use Nerd Font round caps:  (U+E0B6)  (U+E0B4)

set -g status-style "bg=default,fg=#bdb3d6"
set -g status-justify left
set -g status-left-length 40
set -g status-right-length 80
set -g window-status-separator " "

set -g status-left "#[fg=#9a8cc8,bg=default]#[fg=#0e1328,bg=#9a8cc8,bold]  #S #[fg=#9a8cc8,bg=default,nobold] "
set -g window-status-format "#[fg=#6b6f9a] #I #W#{?window_zoomed_flag, 󰊓,} "
set -g window-status-current-format "#[fg=#e8a95b,bg=default]#[fg=#0e1328,bg=#e8a95b,bold]#I #W#{?window_zoomed_flag, 󰊓,}#[fg=#e8a95b,bg=default,nobold]"
set -g status-right "#[fg=#2a2f55,bg=default]#[fg=#d6cfe8,bg=#2a2f55]  #{b:pane_current_path} #[fg=#2a2f55,bg=default] #[fg=#2a2f55,bg=default]#[fg=#e8a95b,bg=#2a2f55]  %H:%M #[fg=#2a2f55,bg=default]"

set -g pane-border-style "fg=#2a2f55,bg=default"
set -g pane-active-border-style "fg=#9a8cc8,bg=default"
set -g pane-border-lines single
set -g message-style "fg=#e8a95b,bg=#2a2f55"
set -g message-command-style "fg=#d79bc9,bg=#2a2f55"
set -g mode-style "fg=#0e1328,bg=#e8a95b"
set -g clock-mode-colour "#e8a95b"
set -g popup-border-style "fg=#9a8cc8"
set -g popup-border-lines rounded
set -g @floax-border-color '#9a8cc8'
set -g @floax-text-color '#d6cfe8'
```

Edit `tmux/tmux.conf`:
1. `copy-pipe-and-cancel "wl-copy"` → `copy-pipe-and-cancel "xclip -in -selection clipboard"`
2. Delete `set -g @plugin 'omerxx/catppuccin-tmux' ...` and every `set -g @catppuccin_*` line (including the two commented ones).
3. Delete the old `pane-active-border-style` / `pane-border-style` lines (theme owns them).
4. Immediately before `run '~/.tmux/plugins/tpm/tpm'` add:

```tmux
# Theme: Nightswim
source-file ~/dotfiles/tmux/nightswim.conf
```

- [ ] **Step 4: Run test** — `bash tests/nightswim/test_tmux.sh` → all `ok`.

- [ ] **Step 5: Reload live sessions** — if a tmux server is running: `tmux source-file ~/.tmux.conf` (catppuccin's leftover options are overwritten by the theme; restart tmux for a fully clean state).

- [ ] **Step 6: Commit**

```bash
git add tmux tests/nightswim/test_tmux.sh
git commit -m "tmux: nightswim pill theme, drop catppuccin, xclip copy"
```

---

### Task 6: fastfetch

**Files:**
- Create: `fastfetch/config.jsonc`, `fastfetch/nightswim.txt`
- Modify: `install-linux.sh`
- Test: `tests/nightswim/test_fastfetch.sh`

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_fastfetch.sh`

```bash
#!/usr/bin/env bash
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
out=$(fastfetch --config "$DOT/fastfetch/config.jsonc" 2>&1); rc=$?
check "exits 0" '[ $rc = 0 ]'
check "no config errors" '! grep -qi "error\|unknown\|invalid" <<<"$out"'
check "boxed sections" '[[ $out == *Software* && $out == *Hardware* ]]'
check "gold logo" '[[ $out == *"38;2;232;169;91m"* ]]'
check "linked" '[ "$(readlink -f ~/.config/fastfetch/config.jsonc)" = "$DOT/fastfetch/config.jsonc" ]'
exit $fail
```

- [ ] **Step 2: Run to verify it fails** — FAIL (no config).

- [ ] **Step 3: Implement** — `fastfetch/nightswim.txt`

```
$1          _.._
$1        .' .-'`
$1       /  /
$1       |  |
$1       \  '.___.;
$1        '._  _.'
$1           ``
$2
$2     .-.    .-.    .-.
$2   .'   `..'   `..'   `.
$3    ~  ~~  ~  ~~  ~  ~~
$3   ~~  ~  ~~  ~  ~~  ~
```

`fastfetch/config.jsonc`:

```jsonc
// Nightswim — palette in ~/dotfiles/nightswim/palette.sh
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "file",
    "source": "~/.config/fastfetch/nightswim.txt",
    "color": { "1": "#e8a95b", "2": "#9a8cc8", "3": "#5a6fb8" },
    "padding": { "top": 2, "left": 2, "right": 4 }
  },
  "display": {
    "separator": " → ",
    "color": { "separator": "#6b6f9a", "output": "#d6cfe8" }
  },
  "modules": [
    "break",
    { "type": "custom", "format": "\u001b[38;2;59;65;112m┌──────────────────── Software ────────────────────┐" },
    { "type": "os",       "key": "OS ",    "keyColor": "#e8a95b" },
    { "type": "kernel",   "key": " ├  ", "keyColor": "#e8a95b" },
    { "type": "packages", "key": " ├ 󰏖 ", "keyColor": "#e8a95b" },
    { "type": "shell",    "key": " ├  ", "keyColor": "#e8a95b" },
    { "type": "terminal", "key": " ├  ", "keyColor": "#e8a95b" },
    { "type": "wm",       "key": " └  ", "keyColor": "#e8a95b" },
    { "type": "custom", "format": "\u001b[38;2;59;65;112m└──────────────────────────────────────────────────┘" },
    { "type": "custom", "format": "\u001b[38;2;59;65;112m┌──────────────────── Hardware ────────────────────┐" },
    { "type": "host",   "key": "PC ",    "keyColor": "#9a8cc8" },
    { "type": "cpu",    "key": " ├  ", "keyColor": "#9a8cc8" },
    { "type": "gpu",    "key": " ├ 󰢮 ", "keyColor": "#9a8cc8" },
    { "type": "memory", "key": " ├  ", "keyColor": "#9a8cc8" },
    { "type": "disk",   "key": " └ 󰋊 ", "keyColor": "#9a8cc8" },
    { "type": "custom", "format": "\u001b[38;2;59;65;112m└──────────────────────────────────────────────────┘" },
    "break",
    { "type": "colors", "symbol": "circle" }
  ]
}
```

Add to `install-linux.sh`:

```bash
# fastfetch
link fastfetch           "$HOME/.config/fastfetch"
```

- [ ] **Step 4: Link and test** — `./install-linux.sh && bash tests/nightswim/test_fastfetch.sh && bash tests/nightswim/test_env.sh` → all `ok` (env's once-only check now passes).

- [ ] **Step 5: Commit**

```bash
git add fastfetch install-linux.sh tests/nightswim/test_fastfetch.sh
git commit -m "fastfetch: nightswim moon logo and boxed sections"
```

---

### Task 7: cava

**Files:**
- Create: `cava/config`
- Modify: `install-linux.sh`
- Test: `tests/nightswim/test_cava.sh`

- [ ] **Step 1: Write the failing test** — `tests/nightswim/test_cava.sh`

```bash
#!/usr/bin/env bash
# cava has no config-check flag: run it in a throwaway tmux pane and look for errors.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "gradient colors" 'grep -q "gradient_color_4 = '"'#e8a95b'"'" "$DOT/cava/config"'
T="tmux -L nscava -f /dev/null"
$T new-session -d -x 80 -y 20 "cava -p '$DOT/cava/config'; sleep 5"; sleep 3
pane=$($T capture-pane -p 2>/dev/null); $T kill-server 2>/dev/null
check "cava starts without config error" '! grep -qi "error\|invalid\|could not" <<<"$pane"'
check "linked" '[ "$(readlink -f ~/.config/cava/config)" = "$DOT/cava/config" ]'
exit $fail
```

- [ ] **Step 2: Run to verify it fails** — FAIL (no config).

- [ ] **Step 3: Implement** — `cava/config`

```ini
; Nightswim cava — palette in ~/dotfiles/nightswim/palette.sh
[general]
framerate = 60
bars = 0
bar_width = 2
bar_spacing = 1

[input]
method = pulse
source = auto

[output]
method = ncurses

[color]
background = default
gradient = 1
gradient_count = 4
gradient_color_1 = '#3b4170'
gradient_color_2 = '#9a8cc8'
gradient_color_3 = '#d79bc9'
gradient_color_4 = '#e8a95b'

[smoothing]
noise_reduction = 77
```

Add to `install-linux.sh`:

```bash
# cava
link cava                "$HOME/.config/cava"
```

- [ ] **Step 4: Link and test** — `./install-linux.sh && bash tests/nightswim/test_cava.sh` → all `ok`.

- [ ] **Step 5: Commit**

```bash
git add cava install-linux.sh tests/nightswim/test_cava.sh
git commit -m "cava: nightswim gradient"
```

---

### Task 8: Regression check, visual check, docs, push

**Files:**
- Create: `tests/nightswim/run_all.sh`, `tests/nightswim/snapshot.sh`
- Modify: `README.md`

- [ ] **Step 1: After snapshot** — `bash tests/nightswim/snapshot.sh ~/.cache/ns-after`

- [ ] **Step 2: Compare with the Task 0 baseline**

```bash
for f in ic lic tmuxkeys; do echo "== $f"; diff ~/.cache/ns-before.$f ~/.cache/ns-after.$f; done
```
Expected — the **only** differences:
- added aliases: `lt`, `lx`, `bat`
- removed functions: `starship_precmd`, `starship_preexec`, `__starship_*`; added: `_ns_prompt`, `_ns_fg`, `__git_ps1` and its helpers
- env added: `FZF_DEFAULT_OPTS`, `BAT_THEME`, `EZA_COLORS`, `VIRTUAL_ENV_DISABLE_PROMPT`; changed value: `LS_COLORS`; removed: `STARSHIP_SHELL`
- PATH identical
- tmux keys: only the `copy-mode-vi y` line differs (`xclip`)

Anything else is a regression — fix before continuing.

- [ ] **Step 3: Run-all script** (tmux options are expected to differ — theme only; `.tmux` snapshot is for eyeballing)

 — `tests/nightswim/run_all.sh`

```bash
#!/usr/bin/env bash
# Run every Nightswim test; exit non-zero if any fails.
cd "$(dirname "$0")" || exit 1
rc=0
for t in test_*.sh; do echo "== $t"; bash "$t" || rc=1; done
exit $rc
```
Run: `bash tests/nightswim/run_all.sh` → every line `ok`.

- [ ] **Step 4: Visual check** — open a fresh Alacritty (`alacritty &`), start `tmux`, split a pane running `cava`, then `gnome-screenshot -f /tmp/ns.png` and view it. Check: wallpaper visible through terminal, panel hidden, prompt/tmux/fastfetch colors readable. Tweak opacity (0.78–0.88) only if text contrast is poor.

- [ ] **Step 5: README** — append to `README.md`:

```markdown
## Linux (Ubuntu) — Nightswim

    git clone git@github.com:aidantiu/dotfiles.git ~/dotfiles
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    sudo apt install -y fastfetch eza git-delta cava fzf bat xclip
    ~/dotfiles/install-linux.sh      # symlink configs (backs up existing files)
    ~/dotfiles/nightswim/desktop.sh  # wallpaper + Hide Top Bar
    # put API keys in ~/.secrets.sh (never committed)

Tests: `bash tests/nightswim/run_all.sh`
```

- [ ] **Step 6: Secret scan, commit, push**

```bash
git add -A
git diff --cached | grep -nE '^\+.*(API_KEY=|gho_|ghp_|sk-[A-Za-z0-9]{10})' && echo STOP || echo clean
git commit -m "nightswim: tests, regression snapshot, README"
git push
```
