# OMP + workmux — Design

**Date:** 2026-10-10
**Machine:** Ubuntu 24.04, GNOME 46 X11, bash, tmux 3.4 (Nightswim theme), dotfiles at `~/dotfiles` (repo `aidantiu/dotfiles`, linked by `install-linux.sh`).

## Goal

A lightweight agent workflow built from **oh-my-pi (`omp`)** and **workmux** (git worktree + tmux window per task), with an **ask-first guard on premium models** inside OMP. Orca stays installed and untouched; this runs alongside it.

**Success:**
- `workmux add <branch> -p "…"` opens a worktree + tmux window running the default agent (OMP), with the right layout for the project.
- In OMP, the first message to a restricted model in a session asks for confirmation; "no" never sends the message and returns to the default model.
- Only installed agents (omp, claude, codex, cursor-agent) appear in workmux.

## User decisions (interview)

| Topic | Decision |
|---|---|
| Restricted models | Fable models, GPT-6 Astra, and the most expensive tier of each provider ("big leagues") — until the user specifies otherwise |
| Restriction behavior | **Ask first**, once per session per model (sub-agents included) |
| Layout | Per project: agent-only by default; **web projects auto-get agent + `npm run dev` + git log** |
| Agents | OMP (default) + Claude Code + Codex + Cursor, **auto-detected** (only installed ones configured) |
| Orca | **Leave as is** — not uninstalled, not disconnected |

## Research facts (2026-10-10)

- OMP = `can1357/oh-my-pi` 18.8.x; install `curl -fsSL https://omp.sh/install | sh`. Config YAML in `~/.omp/agent/` (`config.yml`, `models.yml`), per-project `.omp/config.yml`. Model ids `provider/model[:thinking]`, e.g. `openai-codex/gpt-6-astra`.
- OMP has **no native per-model confirmation or spend cap**; `enabledModels` is a scope, not a hard block. Extensions (`~/.omp/agent/extensions/*.ts`, `export default function (pi: ExtensionAPI)`) get `input` (can return `handled: true` to stop a message), `before_subagent_spawn` (returns `{model, block, reason}`), `before_provider_request`, `pi.setModel`, `ctx.models.list()/current()`.
- workmux = `raine/workmux` 0.1.27x; config `~/.config/workmux/config.yaml` + per-project `.workmux.yaml` (project wins). Built-in agent types include `claude`, `codex`, `omp`, `pi` (not cursor). `agents:` profiles (`type`, `command`, `args`, `env`). `workmux setup` installs status hooks (OMP: `~/.omp/agent/extensions/workmux-status.ts`); window names get working/waiting/done icons. `workmux dashboard`.

## Components

### 1. Model guard — `omp/extensions/model-guard.ts` + `omp/model-guard.yml`

- **Restricted set** = union of:
  - `restrict` patterns (default `*fable*`, `*gpt-6-astra*`);
  - **auto big-leagues**: per provider, model(s) with the highest listed input price among models not already name-restricted (e.g. Opus once Fable is restricted; GPT-6 once Astra is), when ≥2 distinct prices remain; providers without prices fall back to name patterns (`*opus*`, `*fable*`, `*-astra*`, `*ultra*`, `*-max*`);
  - minus `allow` patterns (user overrides).
- **Session approvals**: in-memory `Set<modelId>`, reset when the OMP process/session ends.
- **`input` hook**: if `ctx.models.current()` is restricted and not approved → `ctx.ui.confirm("Use <model> (premium)?")`. Yes → approve, let the message through. No → return `handled: true` (message not sent), `pi.setModel(<default role model>)`, notify.
- **`before_subagent_spawn`**: same rule for the sub-agent's model; No → `block: true` with reason.
- **Non-interactive runs** (no UI, e.g. `omp -p`): restricted + unapproved → block with a clear message (never silently spend).
- Pure logic (pattern matching, top-tier detection, decision) in a separate module so it's unit-testable without OMP.

### 2. OMP config — `omp/config.yml`

- Default model role set to a **non-restricted** model so "No" always has a safe target.
- `extensions` / extension dir picks up `model-guard.ts`. Files linked individually into `~/.omp/agent/` (Orca's extensions there are left alone).

### 3. workmux

- **Install** workmux (release binary/installer), link nothing into `~/.config/workmux` directly — config is **generated**.
- **`bin/wm-agents`**: detects `omp`, `claude`, `codex`, `cursor-agent` on PATH; renders `workmux/config.template.yaml` → `~/.config/workmux/config.yaml` with an `agents:` block for installed ones and `agent:` = first of omp → claude → codex → cursor. Run by `install-linux.sh`; rerun after (un)installing an agent.
- **Layouts**: `solo` (agent) default; `with-dev` (agent + `npm run dev` + `git log --oneline --graph`). Auto-select `with-dev` when the worktree has a `package.json` with a `dev` script. Mechanism verified at build: a layout flag via a thin `wm` wrapper if workmux supports it, otherwise a `post_create` hook. A project `.workmux.yaml` overrides.
- **Status**: `workmux setup` for omp/claude/codex hooks; tmux window icons must render inside the Nightswim pills (verify formats). Cursor: best-effort.
- **Dashboard**: tmux binding `prefix + w` → `workmux dashboard` (only if `w` isn't user-bound; default tmux `w` choose-tree is replaced — noted to user).

## Error handling

- Missing agent binaries never break workmux (not listed).
- Guard config missing/invalid → fall back to defaults (`*fable*`, `*gpt-6-astra*`, auto top-tier) and warn once; never fail open silently.
- `ctx.models.list()` without prices → name-pattern fallback.

## Testing

- `model-guard` logic (bun/node test or omp-free harness): restricted patterns, top-tier detection on sample price lists, allow overrides, ask-once-per-session, decline → no send + default model, sub-agent block, non-interactive block.
- Extension loads in real `omp` without errors (smoke).
- `wm-agents` with fake PATH: only installed agents listed; default precedence.
- Layout auto-selection for web / non-web worktrees.
- `workmux` config validates; tmux config still loads (existing suite stays green).

## Out of scope

Orca removal/disconnection; Claude Code / Codex / Cursor model restrictions (guard is OMP-only); spend budgets.
