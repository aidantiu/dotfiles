// Nightswim model guard — pure policy (no OMP imports, unit-tested with node --test).
//
// restricted(m) = NOT allow-matched AND (restrict-pattern match OR cost.input >= priceThreshold)
// A model with no price (cost.input missing or 0) is judged by name patterns only.
export type ModelInfo = { provider: string; id: string; name?: string; cost?: { input?: number; output?: number } };
export type GuardConfig = { restrict: string[]; allow: string[]; priceThreshold: number };

export const DEFAULT_CONFIG: GuardConfig = {
  restrict: ["*fable*", "*astra*", "*mythos*", "*-pro", "*-pro-*"],
  // User ruling: Opus and OpenAI's Sol/Luna/Terra families never ask (allow beats price and names).
  allow: ["*opus*", "*-sol", "*-sol-*", "*-luna", "*-luna-*", "*-terra", "*-terra-*"],
  priceThreshold: 4, // USD per 1M input tokens; 0 disables the price rule
};

export const modelKey = (m: ModelInfo) => `${m.provider}/${m.id}`;

export function globMatch(pattern: string, text: string): boolean {
  const re = pattern.toLowerCase().replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp(`^${re}$`).test(text.toLowerCase());
}
const anyMatch = (pats: string[], m: ModelInfo) => pats.some((p) => globMatch(p, modelKey(m)) || globMatch(p, m.id));
/** USD per 1M input tokens, or undefined when the catalog has no (non-zero) price. */
export const price = (m: ModelInfo): number | undefined => (m.cost?.input && m.cost.input > 0 ? m.cost.input : undefined);

export function isRestricted(m: ModelInfo, cfg: GuardConfig): boolean {
  if (anyMatch(cfg.allow, m)) return false;
  if (anyMatch(cfg.restrict, m)) return true;
  const p = price(m);
  return cfg.priceThreshold > 0 && p !== undefined && p >= cfg.priceThreshold;
}

/**
 * Model to switch to when `m` is declined: the priciest unrestricted model of the same provider that is
 * strictly cheaper than `m` (unpriced candidates only when `m` itself is unpriced); else `defaultModel`
 * (the configured @default role) when it is unrestricted; else undefined (caller must not send).
 */
export function fallbackFor(m: ModelInfo, all: ModelInfo[], cfg: GuardConfig, defaultModel?: ModelInfo): ModelInfo | undefined {
  const pm = price(m);
  const cheaper = (x: ModelInfo) => {
    const px = price(x);
    return pm === undefined ? true : px !== undefined && px < pm;
  };
  const best = all
    .filter((x) => x.provider === m.provider && modelKey(x) !== modelKey(m) && !isRestricted(x, cfg) && cheaper(x))
    .sort((a, b) => (price(b) ?? 0) - (price(a) ?? 0))[0];
  if (best) return best;
  if (defaultModel && modelKey(defaultModel) !== modelKey(m) && !isRestricted(defaultModel, cfg)) return defaultModel;
  return undefined;
}

/** Approved model keys; a child (sub-agent) view also sees everything its parent approved. */
export class Approvals {
  #keys = new Set<string>();
  #parent?: Approvals;
  constructor(parent?: Approvals) { this.#parent = parent; }
  has(key: string): boolean { return this.#keys.has(key) || (this.#parent?.has(key) ?? false); }
  approve(key: string) { this.#keys.add(key); }
}

// Minimal YAML subset: `restrict:`/`allow:` followed by `  - item` lines, and `priceThreshold: <number>`.
// Full-line and trailing comments are stripped first. Anything else (including the retired
// `autoTopTier`/`fallbackPatterns` keys) → warning + defaults, which fail safe.
export function parseConfig(text: string | undefined): { config: GuardConfig; warning?: string } {
  if (!text) return { config: { ...DEFAULT_CONFIG } };
  const out: Partial<GuardConfig> = {};
  let list: string[] | undefined;
  for (const raw of text.split("\n")) {
    const line = raw.replace(/^\s*#.*$/, "").replace(/\s+#.*$/, "").trimEnd();
    if (!line.trim()) continue;
    let mm: RegExpMatchArray | null;
    if ((mm = line.match(/^(restrict|allow):\s*$/))) { list = out[mm[1] as "restrict" | "allow"] = []; continue; }
    if ((mm = line.match(/^priceThreshold:\s*(\d+(?:\.\d+)?)\s*$/))) { out.priceThreshold = Number(mm[1]); list = undefined; continue; }
    if ((mm = line.match(/^\s+-\s+(['"]?)(.+)\1\s*$/)) && list) { list.push(mm[2]); continue; }
    return { config: { ...DEFAULT_CONFIG }, warning: `model-guard.yml: cannot parse line "${raw.trim()}" — using defaults` };
  }
  return { config: { ...DEFAULT_CONFIG, ...out } };
}
