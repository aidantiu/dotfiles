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
// Full-line comments and trailing comments are stripped first.
export function parseConfig(text: string | undefined): { config: GuardConfig; warning?: string } {
  if (!text) return { config: { ...DEFAULT_CONFIG } };
  const out: Partial<GuardConfig> = {};
  let list: string[] | undefined;
  for (const raw of text.split("\n")) {
    const line = raw.replace(/^\s*#.*$/, "").replace(/\s+#.*$/, "").trimEnd();
    if (!line.trim()) continue;
    let mm: RegExpMatchArray | null;
    if ((mm = line.match(/^(restrict|allow|fallbackPatterns):\s*$/))) { list = (out as any)[mm[1]] = []; continue; }
    if ((mm = line.match(/^autoTopTier:\s*(true|false)\s*$/))) { out.autoTopTier = mm[1] === "true"; list = undefined; continue; }
    if ((mm = line.match(/^\s+-\s+(['"]?)(.+)\1\s*$/)) && list) { list.push(mm[2]); continue; }
    return { config: { ...DEFAULT_CONFIG }, warning: `model-guard.yml: cannot parse line "${raw.trim()}" — using defaults` };
  }
  return { config: { ...DEFAULT_CONFIG, ...out } };
}
