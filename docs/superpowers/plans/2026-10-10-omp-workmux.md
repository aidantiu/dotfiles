# OMP + workmux Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install oh-my-pi (`omp`) and workmux, add an ask-first guard for premium models inside OMP, and wire workmux (auto-detected agents, web-aware layouts, status icons in the Nightswim tmux bar) into the dotfiles.

**Architecture:** Guard = pure policy module (`omp/model-guard/policy.ts`, unit-tested with `node --test`) + thin OMP extension (`omp/extensions/model-guard.ts`) loaded by absolute path from `omp/config.yml`. End-to-end tests drive real `omp --mode rpc` against a local fake OpenAI-compatible provider, so no test can spend money. workmux config is generated from a template by `bin/wm-agents`; `bin/wm` adds the web layout automatically.

**Tech Stack:** omp 18.8.x (Bun runtime, TS extensions), workmux 0.1.27x, node 26 (`node --test`, native TS stripping), bash, tmux 3.4, python3 (fake provider).

**Spec:** `docs/superpowers/specs/2026-10-10-omp-workmux-design.md`

## Global Constraints

- Default restricted patterns: `*fable*`, `*gpt-6-astra*`; plus auto top tier per provider (highest `cost.input` among models not already name-restricted, only when ≥2 distinct prices remain — e.g. Opus once Fable is name-restricted); unpriced providers use fallback patterns `*opus*`, `*fable*`, `*-astra*`, `*ultra*`, `*-max*`; `allow` patterns override.
- Ask once per session per model (sub-agents included). Decline → message not sent + switch to fallback model. No UI → never run a restricted unapproved model.
- Orca is untouched: never edit/delete `~/.orca`, `~/.omp/agent/extensions/orca-*`, `~/.pi/**`, or the Orca passthrough in `claude/statusline.sh`.
- Tests must never contact a real model provider (fake provider on 127.0.0.1 only; `PI_CODING_AGENT_DIR` points at a temp dir).
- Commit messages carry **no** AI co-author trailer (user rule; `.githooks/commit-msg` also strips them).
- Existing suite `bash tests/nightswim/run_all.sh` stays green.

## Review Focus

1. **Print mode (`omp -p`)** bypasses the `input` hook — a restricted model must still not be used. → e2e test in Task 3.
2. **Model switched mid-session via `/model` or Ctrl+P** to a restricted model — next message must ask. → e2e test in Task 3.
3. **Fallback when a provider has no non-restricted model** — decline must still not send. → unit test Task 1.
4. **Missing/invalid `model-guard.yml`** — defaults apply, guard never fails open. → unit test Task 1.
5. **workmux rewriting tmux window formats** would erase the Nightswim pills — `status_format: false` + our own `@workmux_status` rendering. → test Task 6.

## File Map

| File | Responsibility |
|---|---|
| `omp/model-guard/policy.ts` | Pure logic: config parse, glob, restricted set, fallback, approvals |
| `omp/extensions/model-guard.ts` | OMP wiring: `input`, `before_subagent_spawn`, `session_start` (print mode) |
| `omp/model-guard.yml` | User-editable restrict/allow lists |
| `omp/config.yml` | OMP settings; loads the guard by absolute path (linked to `~/.omp/agent/config.yml`) |
| `tests/omp/policy.test.ts` | Unit tests (node --test) |
| `tests/omp/fake_provider.py` | Local OpenAI-compatible SSE stub, logs requested models |
| `tests/omp/rpc_e2e.mjs` + `tests/nightswim/test_omp_guard.sh` | E2E via `omp --mode rpc` / `omp -p` |
| `workmux/config.template.yaml` | workmux config template (`@@AGENT@@`, `@@AGENTS@@`) |
| `bin/wm-agents` | Detect agents → render `~/.config/workmux/config.yaml` |
| `bin/wm` | `workmux` wrapper: auto `-l with-dev` for web repos |
| `tmux/nightswim.conf` | `@workmux_status` in window pills; `prefix+w` dashboard popup |
| `tests/nightswim/test_workmux.sh` | wm-agents, wm, tmux integration |
| `install-linux.sh`, `README.md` | Links + docs |

---

### Task 0: Install omp and workmux

- [ ] **Step 1: Install** (official installers; both install to `~/.local/bin` or print their path)

```bash
curl -fsSL https://omp.sh/install | sh
curl -fsSL https://raw.githubusercontent.com/raine/workmux/main/scripts/install.sh | bash
```

- [ ] **Step 2: Verify** — `omp --version && workmux --version` → both print versions (omp 18.x, workmux 0.1.x). If either isn't on PATH, add its printed bin dir to PATH in `bash/.bashrc` (after the pnpm block) and re-check.

- [ ] **Step 3: Baseline** — `bash tests/nightswim/run_all.sh` → rc 0.

---

### Task 1: Guard policy module

**Files:** Create `omp/model-guard/policy.ts`, `omp/model-guard.yml`, `tests/omp/policy.test.ts`

**Interfaces — Produces:**
```ts
type ModelInfo = { provider: string; id: string; cost?: { input?: number; output?: number } };
type GuardConfig = { restrict: string[]; allow: string[]; autoTopTier: boolean; fallbackPatterns: string[] };
const DEFAULT_CONFIG: GuardConfig;
function parseConfig(text: string | undefined): { config: GuardConfig; warning?: string };
function modelKey(m: ModelInfo): string;              // "provider/id"
function globMatch(pattern: string, text: string): boolean; // case-insensitive, * wildcard
function isRestricted(m: ModelInfo, all: ModelInfo[], cfg: GuardConfig): boolean;
function fallbackFor(m: ModelInfo, all: ModelInfo[], cfg: GuardConfig): ModelInfo | undefined;
class Approvals { has(key: string): boolean; approve(key: string): void }
```

- [ ] **Step 1: Write failing tests** — `tests/omp/policy.test.ts`

```ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_CONFIG, parseConfig, globMatch, isRestricted, fallbackFor, Approvals, modelKey } from "../../omp/model-guard/policy.ts";

const m = (provider: string, id: string, input?: number) => ({ provider, id, cost: input === undefined ? undefined : { input, output: input * 5 } });
const anthropic = [m("anthropic", "claude-fable-5-1", 30), m("anthropic", "claude-opus-5-5", 15), m("anthropic", "claude-sonnet-5-5", 3), m("anthropic", "claude-haiku-5-5", 1)];
const openai = [m("openai-codex", "gpt-6-astra", 20), m("openai-codex", "gpt-6", 5), m("openai-codex", "gpt-6-mini", 0.5)];
const all = [...anthropic, ...openai];
const cfg = DEFAULT_CONFIG;

test("glob is case-insensitive with * wildcards", () => {
  assert.ok(globMatch("*fable*", "anthropic/Claude-FABLE-5-1"));
  assert.ok(!globMatch("*fable*", "anthropic/claude-sonnet-5-5"));
  assert.ok(globMatch("openai-codex/gpt-6-astra*", "openai-codex/gpt-6-astra-wm"));
});
test("fable and astra are restricted by name", () => {
  assert.ok(isRestricted(anthropic[0], all, cfg));
  assert.ok(isRestricted(openai[0], all, cfg));
});
test("top priced tier per provider is restricted, others are not", () => {
  const p = [m("acme", "big", 10), m("acme", "small", 1)];
  assert.ok(isRestricted(p[0], p, cfg));
  assert.ok(!isRestricted(p[1], p, cfg));
});
test("big leagues = top tier after name-restricted models (opus, gpt-6)", () => {
  assert.ok(isRestricted(anthropic[1], all, cfg));   // opus
  assert.ok(!isRestricted(anthropic[2], all, cfg));  // sonnet
  assert.ok(isRestricted(openai[1], all, cfg));      // gpt-6
  assert.ok(!isRestricted(openai[2], all, cfg));     // gpt-6-mini
});
test("single-price provider is not auto-restricted", () => {
  const p = [m("solo", "only", 9)];
  assert.ok(!isRestricted(p[0], p, cfg));
});
test("unpriced provider falls back to name patterns", () => {
  const p = [m("x", "thing-ultra"), m("x", "thing-lite")];
  assert.ok(isRestricted(p[0], p, cfg));
  assert.ok(!isRestricted(p[1], p, cfg));
});
test("allow overrides restrict and top tier", () => {
  const c = { ...cfg, allow: ["*fable*"] };
  assert.ok(!isRestricted(anthropic[0], all, c));
});
test("fallback is the priciest unrestricted model of the same provider", () => {
  assert.equal(modelKey(fallbackFor(anthropic[0], all, cfg)!), "anthropic/claude-sonnet-5-5");
  assert.equal(modelKey(fallbackFor(openai[0], all, cfg)!), "openai-codex/gpt-6-mini");
});
test("no unrestricted model in provider → undefined (caller must still not send)", () => {
  const p = [m("acme", "fable-a", 10), m("acme", "fable-b", 5)];
  assert.equal(fallbackFor(p[0], p, cfg), undefined);
});
test("config parse: lists, booleans, and defaults on missing/invalid", () => {
  const { config } = parseConfig("restrict:\n  - '*foo*'\nallow:\n  - \"*bar*\"\nautoTopTier: false\n");
  assert.deepEqual(config.restrict, ["*foo*"]);
  assert.deepEqual(config.allow, ["*bar*"]);
  assert.equal(config.autoTopTier, false);
  assert.deepEqual(parseConfig(undefined).config, DEFAULT_CONFIG);
  const bad = parseConfig("restrict: [unclosed");
  assert.deepEqual(bad.config, DEFAULT_CONFIG);
  assert.ok(bad.warning);
});
test("approvals are per model key", () => {
  const a = new Approvals();
  a.approve("anthropic/claude-fable-5-1");
  assert.ok(a.has("anthropic/claude-fable-5-1"));
  assert.ok(!a.has("openai-codex/gpt-6-astra"));
});
```

- [ ] **Step 2: Run, expect FAIL** — `node --test tests/omp/policy.test.ts` → module not found.

- [ ] **Step 3: Implement** — `omp/model-guard/policy.ts`

```ts
// Nightswim model guard — pure policy (no OMP imports, unit-tested with node --test).
export type ModelInfo = { provider: string; id: string; cost?: { input?: number; output?: number } };
export type GuardConfig = { restrict: string[]; allow: string[]; autoTopTier: boolean; fallbackPatterns: string[] };

export const DEFAULT_CONFIG: GuardConfig = {
  restrict: ["*fable*", "*gpt-6-astra*"],
  allow: [],
  autoTopTier: true,
  fallbackPatterns: ["*opus*", "*fable*", "*-astra*", "*ultra*", "*-max*"],
};

export const modelKey = (m: ModelInfo) => `${m.provider}/${m.id}`;

export function globMatch(pattern: string, text: string): boolean {
  const re = pattern.toLowerCase().replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp(`^${re}$`).test(text.toLowerCase());
}
const anyMatch = (pats: string[], m: ModelInfo) => pats.some((p) => globMatch(p, modelKey(m)) || globMatch(p, m.id));

function topTier(m: ModelInfo, all: ModelInfo[], cfg: GuardConfig): boolean {
  const same = all.filter((x) => x.provider === m.provider && !anyMatch(cfg.restrict, x));
  const priced = same.filter((x) => (x.cost?.input ?? 0) > 0);
  if (priced.length === 0) return anyMatch(cfg.fallbackPatterns, m);
  if (new Set(priced.map((x) => x.cost!.input)).size < 2) return false;
  const max = Math.max(...priced.map((x) => x.cost!.input!));
  return (m.cost?.input ?? 0) === max;
}

export function isRestricted(m: ModelInfo, all: ModelInfo[], cfg: GuardConfig): boolean {
  if (anyMatch(cfg.allow, m)) return false;
  if (anyMatch(cfg.restrict, m)) return true;
  return cfg.autoTopTier && topTier(m, all, cfg);
}

export function fallbackFor(m: ModelInfo, all: ModelInfo[], cfg: GuardConfig): ModelInfo | undefined {
  return all
    .filter((x) => x.provider === m.provider && !isRestricted(x, all, cfg))
    .sort((a, b) => (b.cost?.input ?? 0) - (a.cost?.input ?? 0))[0];
}

export class Approvals {
  #keys = new Set<string>();
  has(key: string) { return this.#keys.has(key); }
  approve(key: string) { this.#keys.add(key); }
}

// Minimal YAML subset: `key:` followed by `  - item` lines, or `key: true|false`.
export function parseConfig(text: string | undefined): { config: GuardConfig; warning?: string } {
  if (!text) return { config: { ...DEFAULT_CONFIG } };
  const out: Partial<GuardConfig> = {};
  let list: string[] | undefined;
  for (const raw of text.split("\n")) {
    const line = raw.replace(/\s+#.*$/, "").trimEnd();
    if (!line.trim()) continue;
    let mm: RegExpMatchArray | null;
    if ((mm = line.match(/^(restrict|allow|fallbackPatterns):\s*$/))) { list = (out as any)[mm[1]] = []; continue; }
    if ((mm = line.match(/^autoTopTier:\s*(true|false)\s*$/))) { out.autoTopTier = mm[1] === "true"; list = undefined; continue; }
    if ((mm = line.match(/^\s+-\s+(['"]?)(.+)\1\s*$/)) && list) { list.push(mm[2]); continue; }
    return { config: { ...DEFAULT_CONFIG }, warning: `model-guard.yml: cannot parse line "${raw.trim()}" — using defaults` };
  }
  return { config: { ...DEFAULT_CONFIG, ...out } };
}
```

`omp/model-guard.yml`:

```yaml
# Nightswim model guard — models that ask before use (once per session per model).
# Patterns match "provider/model" or the bare model id; * is a wildcard.
restrict:
  - "*fable*"
  - "*gpt-6-astra*"
# Never ask for these (overrides restrict and the auto top tier):
allow:
# Also restrict each provider's most expensive tier ("big leagues"):
autoTopTier: true
```

- [ ] **Step 4: Run, expect PASS** — `node --test tests/omp/policy.test.ts` → all pass.

- [ ] **Step 5: Commit** — `git add omp tests/omp && git commit -m "omp: model guard policy"`

---

### Task 2: Fake provider + e2e harness (no guard yet → tests RED)

**Files:** Create `tests/omp/fake_provider.py`, `tests/omp/rpc_e2e.mjs`, `tests/nightswim/test_omp_guard.sh`

- [ ] **Step 1: Fake provider** — `tests/omp/fake_provider.py`

```python
#!/usr/bin/env python3
"""OpenAI-compatible chat.completions stub on 127.0.0.1. Appends each requested
model id to LOG (argv[2]) and streams a one-word reply. argv[1] = port file."""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = sys.argv[2]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        with open(LOG, "a") as f: f.write(body.get("model", "?") + "\n")
        self.send_response(200); self.send_header("content-type", "text/event-stream"); self.end_headers()
        chunk = {"id": "x", "object": "chat.completion.chunk", "model": body.get("model"),
                 "choices": [{"index": 0, "delta": {"role": "assistant", "content": "ok"}, "finish_reason": None}]}
        done = {**chunk, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}}
        for c in (chunk, done): self.wfile.write(f"data: {json.dumps(c)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")

srv = HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(srv.server_address[1]))
srv.serve_forever()
```

- [ ] **Step 2: RPC driver** — `tests/omp/rpc_e2e.mjs` (spawns `omp --mode rpc [--no-ui] --model <m>`, sends prompts, answers confirms from a script, prints a JSON summary)

```js
// Usage: node rpc_e2e.mjs <model> <answers-csv: yes|no per confirm> <prompts...> [--no-ui]
// Prints {"confirms":N,"titles":[...],"results":[...],"finalModel":"provider/id"}
import { spawn } from "node:child_process";
import readline from "node:readline";
const args = process.argv.slice(2);
const noUi = args.includes("--no-ui");
const [model, answersCsv, ...prompts] = args.filter((a) => a !== "--no-ui");
const answers = answersCsv ? answersCsv.split(",") : [];
const child = spawn("omp", ["--mode", "rpc", ...(noUi ? ["--no-ui"] : []), "--model", model, "--no-session"], { stdio: ["pipe", "pipe", "inherit"] });
const send = (o) => child.stdin.write(JSON.stringify(o) + "\n");
const out = { confirms: 0, titles: [], results: [], finalModel: null };
let pending = null, n = 0;
const next = () => {
  if (n < prompts.length) { const id = `p${n}`; send({ id, type: "prompt", message: prompts[n++] }); pending = id; }
  else send({ id: "state", type: "get_state" });
};
readline.createInterface({ input: child.stdout }).on("line", (line) => {
  let msg; try { msg = JSON.parse(line); } catch { return; }
  if (msg.type === "extension_ui_request" && msg.method === "confirm") {
    out.confirms++; out.titles.push(`${msg.title} ${msg.message ?? ""}`);
    send({ type: "extension_ui_response", id: msg.id, confirmed: (answers.shift() ?? "no") === "yes" });
  } else if ((msg.type === "prompt_result" && msg.id === pending) ||
             (msg.type === "response" && msg.command === "prompt" && msg.data?.agentInvoked === false && msg.id === pending)) {
    out.results.push(msg.status ?? "local"); pending = null; next();
  } else if (msg.type === "response" && msg.id === "state") {
    const m = msg.data?.model; out.finalModel = m ? `${m.provider}/${m.id}` : null;
    console.log(JSON.stringify(out)); child.kill();
  }
});
setTimeout(() => { console.log(JSON.stringify({ ...out, timeout: true })); child.kill(); process.exit(1); }, 60000);
next();
```

- [ ] **Step 3: E2E test script** — `tests/nightswim/test_omp_guard.sh`

```bash
#!/usr/bin/env bash
# End-to-end: real omp + model-guard against a local fake provider (never a real API).
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
command -v omp >/dev/null || { echo "FAIL omp not installed"; exit 1; }
tmp=$(mktemp -d); trap 'kill $FP 2>/dev/null; rm -rf "$tmp"' EXIT
python3 -I "$DOT/tests/omp/fake_provider.py" "$tmp/port" "$tmp/req.log" & FP=$!
for i in $(seq 1 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
export PI_CODING_AGENT_DIR="$tmp/agent" MODEL_GUARD_CONFIG="$DOT/omp/model-guard.yml"
mkdir -p "$PI_CODING_AGENT_DIR"
cat > "$PI_CODING_AGENT_DIR/models.yml" <<EOF
providers:
  fakeco:
    baseUrl: http://127.0.0.1:$(cat "$tmp/port")/v1
    api: openai-completions
    apiKey: fake
    models:
      - { id: fake-fable-5, name: Fake Fable, cost: { input: 30, output: 150, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
      - { id: fake-sonnet, name: Fake Sonnet, cost: { input: 3, output: 15, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
      - { id: fake-mini, name: Fake Mini, cost: { input: 0.3, output: 1.5, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 1024 }
EOF
printf 'extensions:\n  - %s\n' "$DOT/omp/extensions/model-guard.ts" > "$PI_CODING_AGENT_DIR/config.yml"
E="node $DOT/tests/omp/rpc_e2e.mjs"; F=fakeco/fake-fable-5
reqs() { grep -c "$1" "$tmp/req.log" 2>/dev/null || echo 0; }

: > "$tmp/req.log"; o=$($E $F no "hello")
check "decline: asked once" '[[ $o == *"\"confirms\":1"* ]]'
check "decline: fable never called" '[ "$(reqs fake-fable-5)" = 0 ]'
check "decline: switched to fallback (fake-mini)" '[[ $o == *"\"finalModel\":\"fakeco/fake-mini\""* ]]'

: > "$tmp/req.log"; o=$($E $F yes "one" "two")
check "accept: asked once for two messages" '[[ $o == *"\"confirms\":1"* ]]'
check "accept: fable called" '[ "$(reqs fake-fable-5)" -ge 2 ]'

: > "$tmp/req.log"; o=$($E fakeco/fake-mini "" "hi")
check "unrestricted model: no question" '[[ $o == *"\"confirms\":0"* ]] && [ "$(reqs fake-mini)" -ge 1 ]'

: > "$tmp/req.log"; o=$($E $F "" "hi" --no-ui)
check "no UI: restricted model never called" '[ "$(reqs fake-fable-5)" = 0 ]'

: > "$tmp/req.log"; timeout 60 omp -p --no-session --model $F "hi" >/dev/null 2>&1
check "print mode (-p): restricted model never called" '[ "$(reqs fake-fable-5)" = 0 ]'

: > "$tmp/req.log"; o=$($E fakeco/fake-mini yes "hi" "/model fakeco/fake-fable-5" "again")
check "switch to fable mid-session: asks before use" '[[ $o == *"\"confirms\":1"* ]]'
exit $fail
```

- [ ] **Step 4: Run, expect FAIL** — `bash tests/nightswim/test_omp_guard.sh` → extension file missing / decline checks FAIL (fable gets called). If omp rejects `--no-session` or the models.yml shape, fix the harness (not the guard) until failures are only guard-related; ledger each fix.

- [ ] **Step 5: Commit** — `git add tests && git commit -m "tests: omp guard e2e harness with fake provider"`

---

### Task 3: model-guard extension

**Files:** Create `omp/extensions/model-guard.ts`

**Interfaces — Consumes:** Task 1 exports. OMP: `pi.on("input"|"session_start"|"before_subagent_spawn")`, `ctx.ui.confirm(title, message)`, `ctx.ui.notify`, `ctx.hasUI`, `ctx.mode`, `ctx.models.list()/current()/resolve()`, `pi.setModel(model): Promise<boolean>`.

- [ ] **Step 1: Implement**

```ts
// Nightswim model guard for oh-my-pi: premium models ask once per session per model.
// Policy: ../model-guard/policy.ts · config: ~/dotfiles/omp/model-guard.yml (MODEL_GUARD_CONFIG overrides)
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { Approvals, fallbackFor, isRestricted, modelKey, parseConfig, type ModelInfo } from "../model-guard/policy.ts";

const CONFIG = process.env.MODEL_GUARD_CONFIG ?? `${homedir()}/dotfiles/omp/model-guard.yml`;

export default function (pi: any) {
  const approvals = new Approvals();
  let warned = false;
  const config = (ctx: any) => {
    let text: string | undefined;
    try { text = readFileSync(CONFIG, "utf8"); } catch {}
    const { config, warning } = parseConfig(text);
    if (warning && !warned) { warned = true; ctx.ui?.notify?.(warning, "warning"); }
    return config;
  };
  const label = (m: ModelInfo & { name?: string }) => m.name ?? modelKey(m);

  // true = may proceed with `m`
  async function gate(ctx: any, m: ModelInfo | undefined, what: string): Promise<boolean> {
    if (!m) return true;
    const all: ModelInfo[] = ctx.models.list();
    const cfg = config(ctx);
    if (!isRestricted(m, all, cfg) || approvals.has(modelKey(m))) return true;
    if (ctx.hasUI && ctx.mode !== "print") {
      const ok = await ctx.ui.confirm("Premium model", `Use ${label(m)} for ${what}? (asked once per session)`);
      if (ok) { approvals.approve(modelKey(m)); return true; }
    }
    return false;
  }

  async function fallBack(ctx: any, m: ModelInfo) {
    const fb = fallbackFor(m, ctx.models.list(), config(ctx));
    if (fb && (await pi.setModel(fb))) ctx.ui?.notify?.(`Not sent. Switched to ${label(fb)}.`, "info");
    else ctx.ui?.notify?.(`Not sent. ${label(m)} needs approval; pick another model with /model.`, "warning");
  }

  pi.on("input", async (_e: any, ctx: any) => {
    const m = ctx.models.current();
    if (await gate(ctx, m, "this session")) return;
    await fallBack(ctx, m);
    return { handled: true };
  });

  // Print mode skips `input`: never start a run on an unapproved restricted model.
  pi.on("session_start", async (_e: any, ctx: any) => {
    if (ctx.mode !== "print") return;
    const m = ctx.models.current();
    if (!(await gate(ctx, m, "this run"))) await fallBack(ctx, m);
  });

  pi.on("before_subagent_spawn", async (e: any, ctx: any) => {
    for (const p of e.patterns ?? []) {
      const m = ctx.models.resolve(p);
      if (!(await gate(ctx, m, `sub-agent "${e.agent}"`))) {
        return { block: true, reason: `${m ? label(m) : p} is a premium model and was not approved` };
      }
    }
  });
}
```

- [ ] **Step 2: Run e2e** — `bash tests/nightswim/test_omp_guard.sh` → all `ok`. If print-mode still calls fable (setModel in `session_start` too late), move that check to `before_agent_start` with `ctx.abort()` and ledger the ruling; if `/model` via RPC prompt isn't a command path, replace that test step with an RPC `{"type":"set_model","provider":"fakeco","modelId":"fake-fable-5"}` before "again" and ledger.

- [ ] **Step 3: Unit tests still green** — `node --test tests/omp/policy.test.ts`.

- [ ] **Step 4: Commit** — `git add omp && git commit -m "omp: model-guard extension (ask once per session per premium model)"`

---

### Task 4: OMP config + linking

**Files:** Create `omp/config.yml`; Modify `install-linux.sh`

- [ ] **Step 1: Test first** — append to `tests/nightswim/test_omp_guard.sh` before `exit`:

```bash
check "global config links to dotfiles" '[ "$(readlink -f ~/.omp/agent/config.yml)" = "$DOT/omp/config.yml" ]'
check "global config loads model-guard" 'grep -q "$DOT/omp/extensions/model-guard.ts" "$DOT/omp/config.yml"'
check "orca extensions untouched" 'ls ~/.omp/agent/extensions/orca-agent-status.ts >/dev/null'
```
Run → the two config checks FAIL.

- [ ] **Step 2: Implement** — `omp/config.yml` (only the guard; everything else stays OMP default until the user changes it with `omp config set`, which writes here):

```yaml
# oh-my-pi settings (linked to ~/.omp/agent/config.yml). `omp config set` edits this file.
extensions:
  - ~/dotfiles/omp/extensions/model-guard.ts
```
If omp does not expand `~` in `extensions` (check: `omp config get extensions` / a startup warning), install-linux.sh renders the absolute path instead and the test uses the rendered value; ledger it.

`install-linux.sh` (after the cava block): `link omp/config.yml "$HOME/.omp/agent/config.yml"` (backs up an existing one).

- [ ] **Step 3: Run** — `./install-linux.sh && bash tests/nightswim/test_omp_guard.sh` → all ok.
- [ ] **Step 4: Commit** — `git commit -m "omp: link config, load model guard"`

---

### Task 5: workmux config generator (`bin/wm-agents`)

**Files:** Create `workmux/config.template.yaml`, `bin/wm-agents`, `tests/nightswim/test_workmux.sh`; Modify `install-linux.sh`

- [ ] **Step 1: Failing test** — `tests/nightswim/test_workmux.sh`

```bash
#!/usr/bin/env bash
# workmux: agent detection, web-aware layout wrapper, tmux integration.
DOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fakebin() { mkdir -p "$tmp/bin$1"; for a in "${@:2}"; do printf '#!/bin/sh\n' > "$tmp/bin$1/$a"; chmod +x "$tmp/bin$1/$a"; done; }

fakebin 1 omp claude codex cursor-agent
PATH="$tmp/bin1:/usr/bin:/bin" "$DOT/bin/wm-agents" "$tmp/c1.yaml" >/dev/null
check "all four agents listed" 'for a in omp claude codex cursor; do grep -q "^  $a:" "$tmp/c1.yaml" || exit 1; done'
check "omp is default" 'grep -q "^agent: omp$" "$tmp/c1.yaml"'
fakebin 2 claude codex
PATH="$tmp/bin2:/usr/bin:/bin" "$DOT/bin/wm-agents" "$tmp/c2.yaml" >/dev/null
check "only installed agents" '! grep -qE "^  (omp|cursor):" "$tmp/c2.yaml" && grep -q "^  claude:" "$tmp/c2.yaml"'
check "claude default when no omp" 'grep -q "^agent: claude$" "$tmp/c2.yaml"'
check "valid YAML" 'python3 -I -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$tmp/c1.yaml"'
check "status_format off (keeps Nightswim pills)" 'grep -q "^status_format: false" "$tmp/c1.yaml"'
check "with-dev layout defined" 'grep -q "^  with-dev:" "$tmp/c1.yaml"'
check "live config generated" '[ -f ~/.config/workmux/config.yaml ] && grep -q "^agents:" ~/.config/workmux/config.yaml'
exit $fail
```
Run → FAIL (wm-agents missing).

- [ ] **Step 2: Template** — `workmux/config.template.yaml`

```yaml
# workmux config — GENERATED by ~/dotfiles/bin/wm-agents from workmux/config.template.yaml.
# Edit the template, then run `wm-agents`.
nerdfont: true
status_format: false   # Nightswim tmux pills render #{@workmux_status} themselves
agent: @@AGENT@@
agents:
@@AGENTS@@
panes:
  - command: <agent>
    focus: true
layouts:
  solo:
    panes:
      - command: <agent>
        focus: true
  with-dev:
    panes:
      - command: <agent>
        focus: true
      - command: npm run dev
        split: horizontal
      - command: git log --oneline --graph --decorate
        split: vertical
files:
  copy:
    - .env
    - .env.local
```

- [ ] **Step 3: Generator** — `bin/wm-agents`

```bash
#!/usr/bin/env bash
# Detect installed coding agents and render the workmux config.
#   wm-agents [output]   (default ~/.config/workmux/config.yaml)
set -euo pipefail
DOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
out="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/workmux/config.yaml}"
agents=""; default=""
add() { # add <name> <binary> <yaml body>
  command -v "$2" >/dev/null || return 0
  agents+="  $1: $3"$'\n'; [ -n "$default" ] || default="$1"
}
add omp    omp          "{ type: omp, command: omp }"
add claude claude       "{ type: claude, command: claude }"
add codex  codex        "{ type: codex, command: codex }"
add cursor cursor-agent "{ command: cursor-agent }"
[ -n "$default" ] || { echo "wm-agents: no agent CLI found (omp, claude, codex, cursor-agent)" >&2; exit 1; }
mkdir -p "$(dirname "$out")"
awk -v agent="$default" -v agents="${agents%$'\n'}" '
  /@@AGENTS@@/ { print agents; next } { gsub(/@@AGENT@@/, agent); print }' \
  "$DOT/workmux/config.template.yaml" > "$out.tmp" && mv "$out.tmp" "$out"
echo "workmux agents: $(grep -oE '^  [a-z]+:' "$out" | tr -d ' :' | paste -sd' ') (default: $default)"
```

`install-linux.sh` (after the nsws link): `link bin/wm-agents "$HOME/.local/bin/wm-agents"` then `"$DOT/bin/wm-agents" >/dev/null || true`.

- [ ] **Step 4: Run** — `chmod +x bin/wm-agents && ./install-linux.sh && bash tests/nightswim/test_workmux.sh` → all ok. Also `workmux config path` / a dry `workmux list` in this repo → no config error.
- [ ] **Step 5: Commit** — `git commit -m "workmux: generated config with auto-detected agents"`

---

### Task 6: `wm` wrapper + tmux integration

**Files:** Create `bin/wm`; Modify `tmux/nightswim.conf`, `tests/nightswim/test_workmux.sh`, `tests/nightswim/test_tmux.sh`, `install-linux.sh`

- [ ] **Step 1: Failing tests** — append to `test_workmux.sh` before `exit`:

```bash
# wm: prints the workmux command it would run when WM_DRY_RUN=1
web="$tmp/web"; plain="$tmp/plain"
for r in "$web" "$plain"; do git init -q "$r"; done
echo '{"scripts":{"dev":"vite"}}' > "$web/package.json"
echo '{"scripts":{"build":"tsc"}}' > "$plain/package.json"
w() { (cd "$1" && WM_DRY_RUN=1 "$DOT/bin/wm" "${@:2}"); }
check "web repo: add gets -l with-dev" '[ "$(w "$web" add feat -p hi)" = "workmux add -l with-dev feat -p hi" ]'
check "non-web repo: plain add" '[ "$(w "$plain" add feat)" = "workmux add feat" ]'
check "explicit layout respected" '[ "$(w "$web" add feat -l solo)" = "workmux add feat -l solo" ]'
check "explicit agent: no layout (workmux forbids both)" '[ "$(w "$web" add feat -a claude)" = "workmux add feat -a claude" ]'
check "other subcommands pass through" '[ "$(w "$web" list)" = "workmux list" ]'
check "wm linked" '[ "$(readlink -f ~/.local/bin/wm)" = "$DOT/bin/wm" ]'
```
and to `test_tmux.sh` before its `kill-server`:

```bash
check "window pills show workmux status" '[[ $(g window-status-format) == *"@workmux_status"* && $(g window-status-current-format) == *"@workmux_status"* ]]'
check "prefix+w opens workmux dashboard" '$T list-keys -T prefix w | grep -q "workmux dashboard"'
```
Run both → new checks FAIL.

- [ ] **Step 2: `bin/wm`**

```bash
#!/usr/bin/env bash
# workmux wrapper: `wm add …` in a web repo (package.json with a "dev" script)
# uses the with-dev layout unless -l/--layout or -a/--agent is given.
set -euo pipefail
run() { if [ "${WM_DRY_RUN:-}" = 1 ]; then echo "$*"; else exec "$@"; fi; }
if [ "${1:-}" = add ]; then
  explicit=0
  for a in "$@"; do case "$a" in -l|--layout|--layout=*|-a|--agent|--agent=*) explicit=1 ;; esac; done
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if [ $explicit = 0 ] && [ -f "$root/package.json" ] &&
     python3 -I -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("scripts",{}).get("dev") else 1)' "$root/package.json" 2>/dev/null; then
    shift; run workmux add -l with-dev "$@"
  fi
fi
run workmux "$@"
```
`install-linux.sh`: `link bin/wm "$HOME/.local/bin/wm"`.

- [ ] **Step 3: tmux** — in `tmux/nightswim.conf` (python-edit so glyphs stay escapes): insert `#{?@workmux_status, #{@workmux_status},}` after `#W` in both `window-status-format` and `window-status-current-format`; append:

```tmux
# workmux dashboard (prefix+w replaces tmux's choose-tree on w)
bind w display-popup -E -w 90% -h 85% -d "#{pane_current_path}" "workmux dashboard"
```

- [ ] **Step 4: Run** — `./install-linux.sh && bash tests/nightswim/test_workmux.sh && bash tests/nightswim/test_tmux.sh` → all ok; `tmux source-file ~/.tmux.conf`.
- [ ] **Step 5: Commit** — `git commit -m "workmux: wm wrapper (auto web layout), status in tmux pills, prefix+w dashboard"`

---

### Task 7: Status hooks, README, full run

- [ ] **Step 1: Status hooks** — run `workmux setup` (it detects omp/claude/codex). If it prompts, answer yes for omp, claude, codex; if it can't run non-interactively, ask the user to run it in their terminal. Verify:

```bash
ls ~/.omp/agent/extensions/workmux-status.ts
```
Append to `test_workmux.sh`: `check "omp status hook installed" '[ -f ~/.omp/agent/extensions/workmux-status.ts ]'`.

- [ ] **Step 2: Smoke** — in a scratch repo: `wm add smoke-test` (OMP opens in a new tmux window); check the window pill shows a status icon after sending a message; `workmux remove smoke-test` (confirm cleanup). Record result in ledger.

- [ ] **Step 3: README** — append:

```markdown
## Agents — oh-my-pi + workmux

    wm add <branch> -p "task"     # worktree + tmux window running the default agent (omp)
    wm add <branch> -a claude     # pick another detected agent (claude, codex, cursor)
    prefix + w                    # workmux dashboard
    wm-agents                     # re-detect agents after installing/removing one

Premium models (Fable, GPT-6 Astra, each provider's top tier) ask once per session in omp.
Edit `omp/model-guard.yml` to change what's restricted.
Tests: `node --test tests/omp/policy.test.ts` and `bash tests/nightswim/run_all.sh`.
```

- [ ] **Step 4: Full suite** — `node --test tests/omp/policy.test.ts && bash tests/nightswim/run_all.sh` → all pass.
- [ ] **Step 5: Commit + push** — `git commit -m "docs: omp + workmux usage" && git push`
