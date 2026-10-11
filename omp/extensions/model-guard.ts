// Nightswim model guard for oh-my-pi: premium models ask once per session per model.
// Policy: ../model-guard/policy.ts · config: ~/dotfiles/omp/model-guard.yml (MODEL_GUARD_CONFIG overrides)
//
// Chokepoints (omp 18.8.7):
//   before_agent_start      — fires for every run in every mode (initial CLI prompt, `c`/`.` continue,
//                             steer/follow-up batches, goal/loop continuations, sub-agent runs): ask / fall back / abort.
//   before_provider_request — backstop for anything else (side questions, compaction, mid-run switches):
//                             an unapproved restricted model is aborted and its payload poisoned, so no request is sent.
//   input                   — UX only: asks before a typed message is consumed (the two above still enforce).
//   before_subagent_spawn   — gates the sub-agent's model (explicit patterns, @role, or inherited) before it spawns.
// Fail closed: omp drops a handler after 30s or on a throw and carries on as "not blocked", so every handler
// catches its own errors and blocks, and the confirm dialog is raced against a 25s timer (timeout = No).
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { Approvals, fallbackFor, globMatch, isRestricted, modelKey, parseConfig, type ModelInfo } from "../model-guard/policy.ts";

const CONFIG = process.env.MODEL_GUARD_CONFIG ?? `${homedir()}/dotfiles/omp/model-guard.yml`;
const CONFIRM_TIMEOUT_MS = Math.min(Number(process.env.MODEL_GUARD_CONFIRM_TIMEOUT_MS) || 25_000, 25_000);

// Factories are re-run for every sub-agent session in the same process; approvals are shared parent → child
// through this registry keyed by omp's agent id (ctx.agent.id / ctx.agent.parentId).
const REGISTRY: Map<string, Approvals> = ((globalThis as any)[Symbol.for("nightswim.model-guard.approvals")] ??= new Map());

/** Poisoned provider payload: any read by the transport throws before a request is built or sent. */
const BLOCKED_PAYLOAD = new Proxy({}, {
  get(_t, prop) {
    if (prop === "then") return undefined; // survives `await`
    throw new Error("model-guard: request blocked (premium model not approved)");
  },
  ownKeys() { throw new Error("model-guard: request blocked (premium model not approved)"); },
});

export default function (pi: any) {
  let warned = false;

  const agentOf = (ctx: any) => ctx?.agent ?? { kind: "main", id: "Main" };
  const isSub = (ctx: any) => agentOf(ctx).kind === "sub";
  const say = (ctx: any, msg: string, level: "info" | "warning" | "error" = "warning") => {
    if (!ctx?.hasUI) process.stderr.write(`model-guard: ${msg}\n`);
    try { ctx?.ui?.notify?.(msg, level); } catch { /* UI gone */ }
  };
  // Keyed by agent id, not a closure variable: works whether omp re-runs the factory per sub-agent or reuses it.
  const store = (ctx: any, fresh = false): Approvals => {
    const a = agentOf(ctx);
    let ap = REGISTRY.get(a.id);
    if (!ap || fresh) {
      ap = new Approvals(a.kind === "sub" && a.parentId ? REGISTRY.get(a.parentId) : undefined);
      REGISTRY.set(a.id, ap);
    }
    return ap;
  };
  const config = (ctx: any) => {
    let text: string | undefined;
    let missing: string | undefined;
    try { text = readFileSync(CONFIG, "utf8"); } catch (err: any) { missing = err?.code ?? "unknown"; }
    const { config, warning } = parseConfig(text);
    const w = missing ? `${CONFIG} not found or unreadable (${missing}) — using defaults` : warning;
    if (w && !warned) { warned = true; say(ctx, w); }
    return config;
  };
  const label = (m: ModelInfo) => m.name ?? modelKey(m);
  const needsApproval = (ctx: any, m: ModelInfo | undefined) => !!m && isRestricted(m, config(ctx)) && !store(ctx).has(modelKey(m));

  // Ask (UI modes only). Resolves false on No, dismissal, error, or after CONFIRM_TIMEOUT_MS (< omp's 30s).
  async function ask(ctx: any, m: ModelInfo, what: string): Promise<boolean> {
    if (!ctx.hasUI || ctx.mode === "print" || ctx.mode === "json" || isSub(ctx)) return false;
    const ac = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const timeout = new Promise<boolean>((resolve) => { timer = setTimeout(() => { ac.abort(); resolve(false); }, CONFIRM_TIMEOUT_MS); });
    const answer = Promise.resolve()
      .then(() => ctx.ui.confirm("Premium model", `Use ${label(m)} for ${what}? (asked once per session)`, { timeout: CONFIRM_TIMEOUT_MS, signal: ac.signal }))
      .then((v: unknown) => v === true, () => false);
    try { return await Promise.race([answer, timeout]); } finally { clearTimeout(timer); }
  }

  // true = may proceed with `m`
  async function gate(ctx: any, m: ModelInfo | undefined, what: string): Promise<boolean> {
    if (!needsApproval(ctx, m)) return true;
    if (await ask(ctx, m!, what)) { store(ctx).approve(modelKey(m!)); return true; }
    return false;
  }

  // true = switched to an unrestricted model
  async function fallBack(ctx: any, m: ModelInfo): Promise<boolean> {
    let def: ModelInfo | undefined;
    try { def = ctx.models.resolve("@default"); } catch { def = undefined; }
    const fb = fallbackFor(m, ctx.models.list(), config(ctx), def);
    if (fb && (await pi.setModel(fb))) { say(ctx, `${label(m)} not approved — switched to ${label(fb)}.`, "info"); return true; }
    return false;
  }
  const refuse = (ctx: any, m: ModelInfo | undefined) => {
    say(ctx, `${m ? label(m) : "this model"} is a premium model and was not approved — not sent. Pick another model with /model.`);
    try { ctx.abort(); } catch { /* nothing running */ }
  };
  const failClosed = (ctx: any, where: string, err: unknown) => {
    say(ctx, `${where} failed (${(err as any)?.message ?? err}) — blocking to be safe`, "error");
  };

  // UX: ask before a typed message is consumed; on No, keep the message out and switch model if possible.
  pi.on("input", async (_e: any, ctx: any) => {
    try {
      const m = ctx.models.current();
      if (await gate(ctx, m, "this session")) return;
      if (!(await fallBack(ctx, m))) refuse(ctx, m);
      return { handled: true };
    } catch (err) { failClosed(ctx, "input", err); return { handled: true }; }
  });

  // Approvals are per session: a new/switched session asks again (sub-agents inherit their parent's).
  pi.on("session_switch", async (_e: any, ctx: any) => { try { store(ctx, true); } catch { /* next gate re-creates */ } });

  // Non-interactive main sessions (print/json/rpc --no-ui) switch away from a restricted model up front.
  pi.on("session_start", async (_e: any, ctx: any) => {
    try {
      store(ctx, true);
      if (isSub(ctx) || (ctx.hasUI && ctx.mode !== "print" && ctx.mode !== "json")) return;
      const m = ctx.models.current();
      if (needsApproval(ctx, m)) await fallBack(ctx, m);
    } catch (err) { failClosed(ctx, "session_start", err); }
  });

  // The chokepoint: every run in every mode passes here before its first provider request.
  pi.on("before_agent_start", async (_e: any, ctx: any) => {
    let m: ModelInfo | undefined;
    try {
      m = ctx.models.current();
      if (await gate(ctx, m, isSub(ctx) ? "this sub-agent" : "this session")) return;
      if (!isSub(ctx) && (await fallBack(ctx, m!))) return; // the backstop still aborts if this run keeps `m`
      refuse(ctx, m);
    } catch (err) { failClosed(ctx, "before_agent_start", err); refuse(ctx, m); }
  });

  // Backstop (no dialog): an unapproved restricted model never reaches the provider.
  pi.on("before_provider_request", async (_e: any, ctx: any) => {
    try {
      const m: ModelInfo | undefined = ctx.model;
      if (!needsApproval(ctx, m)) return;
      refuse(ctx, m);
    } catch (err) { failClosed(ctx, "before_provider_request", err); try { ctx.abort(); } catch { /* idle */ } }
    return BLOCKED_PAYLOAD;
  });

  pi.on("before_subagent_spawn", async (e: any, ctx: any) => {
    try {
      const what = `sub-agent "${e.agent}"`;
      const patterns: string[] = e.patterns?.length ? e.patterns : e.modelRole ? [`@${e.modelRole}`] : [];
      if (patterns.length === 0) { // inherits the parent's model
        const m = ctx.models.current();
        return (await gate(ctx, m, what)) ? undefined : { block: true, reason: `${label(m)} is a premium model and was not approved` };
      }
      for (const p of patterns) {
        const m = ctx.models.resolve(p);
        const ok = m
          ? await gate(ctx, m, what)
          : !config(ctx).restrict.some((r) => globMatch(r, p)) || (await gate(ctx, { provider: "", id: p, name: p }, what));
        if (!ok) return { block: true, reason: `${m ? label(m) : p} is a premium model and was not approved` };
      }
    } catch (err) {
      failClosed(ctx, "before_subagent_spawn", err);
      return { block: true, reason: "model-guard failed; sub-agent blocked to be safe" };
    }
  });

  // Observable proof the extension loaded (shows in the command list); also reports the active policy file.
  pi.registerCommand?.("model-guard", {
    description: "Show the model-guard config in use",
    handler: async (_args: string, ctx: any) => { ctx.ui?.notify?.(`model-guard active, config: ${CONFIG}`, "info"); },
  });
}
