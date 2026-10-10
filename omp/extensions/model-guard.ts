// Nightswim model guard for oh-my-pi: premium models ask once per session per model.
// Policy: ../model-guard/policy.ts · config: ~/dotfiles/omp/model-guard.yml (MODEL_GUARD_CONFIG overrides)
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { Approvals, fallbackFor, globMatch, isRestricted, modelKey, parseConfig, type ModelInfo } from "../model-guard/policy.ts";

const CONFIG = process.env.MODEL_GUARD_CONFIG ?? `${homedir()}/dotfiles/omp/model-guard.yml`;

export default function (pi: any) {
  let approvals = new Approvals();
  let warned = false;
  const config = (ctx: any) => {
    let text: string | undefined;
    let missing: string | undefined;
    try { text = readFileSync(CONFIG, "utf8"); } catch (err: any) { missing = err?.code ?? "unknown"; }
    const { config, warning } = parseConfig(text);
    const w = missing ? `model-guard: ${CONFIG} not found or unreadable (${missing}) — using defaults` : warning;
    if (w && !warned) { warned = true; ctx.ui?.notify?.(w, "warning"); }
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

  // true = switched to an unrestricted model
  async function fallBack(ctx: any, m: ModelInfo): Promise<boolean> {
    const fb = fallbackFor(m, ctx.models.list(), config(ctx));
    if (fb && (await pi.setModel(fb))) { ctx.ui?.notify?.(`Not sent. Switched to ${label(fb)}.`, "info"); return true; }
    ctx.ui?.notify?.(`Not sent. ${label(m)} needs approval; pick another model with /model.`, "warning");
    return false;
  }

  pi.on("input", async (_e: any, ctx: any) => {
    const m = ctx.models.current();
    if (await gate(ctx, m, "this session")) return;
    await fallBack(ctx, m);
    return { handled: true };
  });

  // Approvals are per session: a new/switched session asks again.
  const newSession = () => { approvals = new Approvals(); };
  pi.on("session_switch", newSession);

  // Print mode skips `input`: never start a run on an unapproved restricted model.
  pi.on("session_start", async (_e: any, ctx: any) => {
    newSession();
    if (ctx.mode !== "print") return;
    const m = ctx.models.current();
    if (!(await gate(ctx, m, "this run"))) await fallBack(ctx, m);
  });

  // Print-mode backstop: if the model is still restricted and unapproved (no fallback), abort before any request.
  pi.on("before_agent_start", async (_e: any, ctx: any) => {
    if (ctx.mode !== "print") return;
    const m = ctx.models.current();
    if (await gate(ctx, m, "this run")) return;
    if (await fallBack(ctx, m)) return;
    process.stderr.write(`model-guard: ${label(m!)} is a premium model and no fallback exists — aborting\n`);
    ctx.abort();
  });

  pi.on("before_subagent_spawn", async (e: any, ctx: any) => {
    for (const p of e.patterns ?? []) {
      const m = ctx.models.resolve(p);
      const ok = m
        ? await gate(ctx, m, `sub-agent "${e.agent}"`)
        : !config(ctx).restrict.some((r) => globMatch(r, p)) || (await gate(ctx, { provider: "", id: p, name: p } as ModelInfo, `sub-agent "${e.agent}"`));
      if (!ok) return { block: true, reason: `${m ? label(m) : p} is a premium model and was not approved` };
    }
  });

  // Observable proof the extension loaded (shows in the command list); also reports the active policy file.
  pi.registerCommand?.("model-guard", {
    description: "Show the model-guard config in use",
    handler: async (_args: string, ctx: any) => { ctx.ui?.notify?.(`model-guard active, config: ${CONFIG}`, "info"); },
  });
}
