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
    let missing = false;
    try { text = readFileSync(CONFIG, "utf8"); } catch { missing = true; }
    const { config, warning } = parseConfig(text);
    const w = missing ? `model-guard: ${CONFIG} not found — using defaults` : warning;
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
