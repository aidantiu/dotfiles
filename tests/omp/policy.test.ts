import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DEFAULT_CONFIG, parseConfig, globMatch, isRestricted, fallbackFor, Approvals, modelKey, type ModelInfo } from "../../omp/model-guard/policy.ts";

const m = (provider: string, id: string, input?: number): ModelInfo => ({ provider, id, cost: input === undefined ? undefined : { input, output: input * 5 } });
const cfg = DEFAULT_CONFIG;
const R = (x: ModelInfo, c = cfg) => isRestricted(x, c);

test("glob is case-insensitive with * wildcards", () => {
  assert.ok(globMatch("*fable*", "anthropic/Claude-FABLE-5-1"));
  assert.ok(!globMatch("*fable*", "anthropic/claude-sonnet-5-5"));
  assert.ok(globMatch("openai-codex/gpt-6-astra*", "openai-codex/gpt-6-astra-wm"));
});
test("name patterns restrict regardless of price (fable, astra, mythos, -pro)", () => {
  for (const id of ["claude-fable-5-1", "gpt-6-astra", "claude-mythos-5", "gpt-5.5-pro", "gemini-3.1-pro-preview"])
    assert.ok(R(m("x", id, 0.1)), id);
  assert.ok(R(m("x", "claude-fable-5")), "unpriced fable");
});
test("price threshold: cost.input >= 4 is restricted, below is not", () => {
  assert.ok(R(m("acme", "big", 4)));
  assert.ok(R(m("acme", "huge", 30)));
  assert.ok(!R(m("acme", "small", 3.99)));
});
test("unpriced (or zero-priced) models are judged by name patterns only", () => {
  assert.ok(!R(m("x", "thing-ultra")));
  assert.ok(!R(m("x", "thing", 0)));
});
test("default allow list: opus and sol/luna/terra never ask, even above the threshold", () => {
  for (const id of ["claude-opus-5-5", "claude-opus-4-1", "gpt-5.6-sol", "gpt-6-luna", "gpt-6-terra-wm", "gpt-5.6-terra"])
    assert.ok(!R(m("x", id, 15)), id);
  assert.ok(R(m("x", "console-max", 9)), "bare *sol* must not be allowed (console)");
});
test("allow overrides name patterns and price", () => {
  const c = { ...cfg, allow: ["*fable*"] };
  assert.ok(!R(m("anthropic", "claude-fable-5-1", 30), c));
});
test("priceThreshold 0 disables the price rule", () => {
  assert.ok(!R(m("acme", "huge", 30), { ...cfg, priceThreshold: 0 }));
});

test("fallback: priciest unrestricted model of the provider that is strictly cheaper", () => {
  const all = [m("a", "claude-fable-5-1", 10), m("a", "big", 8), m("a", "claude-opus-5-5", 4), m("a", "claude-sonnet-5-5", 2), m("a", "claude-haiku-5-5", 0.1)];
  assert.equal(modelKey(fallbackFor(all[0], all, cfg)!), "a/claude-opus-5-5");
});
test("fallback is never pricier than the declined model", () => {
  const all = [m("a", "x-astra", 2), m("a", "cheap", 1), m("a", "legacy-pricey", 3.5)];
  assert.equal(modelKey(fallbackFor(all[0], all, cfg)!), "a/cheap");
});
test("fallback: unpriced candidates only when the declined model is unpriced", () => {
  const all = [m("a", "x-fable", 10), m("a", "free-thing")];
  assert.equal(fallbackFor(all[0], all, cfg), undefined);
  const un = [m("a", "x-fable"), m("a", "free-thing")];
  assert.equal(modelKey(fallbackFor(un[0], un, cfg)!), "a/free-thing");
});
test("fallback: no candidate → unrestricted default role model, else undefined", () => {
  const p = [m("acme", "fable-a", 10), m("acme", "fable-b", 5)];
  assert.equal(fallbackFor(p[0], p, cfg), undefined);
  assert.equal(modelKey(fallbackFor(p[0], p, cfg, m("other", "mini", 0.3))!), "other/mini");
  assert.equal(fallbackFor(p[0], p, cfg, m("other", "x-astra", 0.3)), undefined);
  assert.equal(fallbackFor(p[0], p, cfg, p[0]), undefined);
});

// Snapshot of omp 18.8.7's real built-in catalog (ids + cost.input) — see catalog.fixture.json._source.
const catalog = JSON.parse(readFileSync(new URL("./catalog.fixture.json", import.meta.url), "utf8"));
const prov = (p: string): ModelInfo[] => Object.entries(catalog[p] as Record<string, number | null>).map(([id, input]) => m(p, id, input ?? undefined));
const get = (p: string, id: string) => { const x = prov(p).find((y) => y.id === id); assert.ok(x, `${p}/${id} in fixture`); return x!; };

test("catalog: premium models are restricted", () => {
  for (const [p, id] of [
    ["anthropic", "claude-fable-5"], ["anthropic", "claude-fable-5-1"], ["anthropic", "claude-mythos-5"], ["anthropic", "claude-mythos-5-1"],
    ["openai", "gpt-6-astra"], ["openai", "gpt-5.5-pro"], ["openai", "gpt-4"], ["openai", "o1-pro"],
    ["openai-codex", "gpt-6-astra"], ["github-copilot", "claude-fable-5-1".replace("5-1", "5.1")], ["github-copilot", "gpt-6-astra"],
  ]) assert.ok(R(get(p, id)), `${p}/${id}`);
});
test("catalog: opus, sol/luna/terra and cheap models are not restricted", () => {
  for (const [p, id] of [
    ["anthropic", "claude-opus-5"], ["anthropic", "claude-opus-5-5"], ["anthropic", "claude-sonnet-5-5"], ["anthropic", "claude-haiku-5-5"],
    ["openai", "gpt-5-mini"], ["openai", "gpt-5.6-sol"], ["openai", "gpt-6-luna"], ["openai", "gpt-5.6-terra"],
    ["openai-codex", "gpt-5.6-sol"], ["openai-codex", "gpt-6-sol"], ["openai-codex", "gpt-6.1-sol"], ["openai-codex", "gpt-6-luna"], ["openai-codex", "gpt-5.6-terra"],
    ["github-copilot", "claude-opus-5.5"], ["github-copilot", "gpt-5-mini"],
  ]) assert.ok(!R(get(p, id)), `${p}/${id}`);
  for (const p of ["anthropic", "openai", "openai-codex", "github-copilot"])
    for (const x of prov(p)) if (/-(sol|luna|terra)(-|$)|opus/.test(x.id)) assert.ok(!R(x), modelKey(x));
});
test("catalog: declining a restricted model never falls back to a pricier or restricted one", () => {
  for (const p of ["anthropic", "openai", "openai-codex", "github-copilot"]) {
    const all = prov(p);
    for (const x of all.filter((y) => R(y))) {
      const fb = fallbackFor(x, all, cfg);
      if (!fb) continue;
      assert.ok(!R(fb), `${modelKey(x)} → ${modelKey(fb)} restricted`);
      if ((x.cost?.input ?? 0) > 0) assert.ok(fb.cost!.input! < x.cost!.input!, `${modelKey(x)} → ${modelKey(fb)} not cheaper`);
    }
  }
  const astra = fallbackFor(get("openai-codex", "gpt-6-astra"), prov("openai-codex"), cfg)!;
  assert.ok(astra.cost!.input! < 10);
  assert.equal(modelKey(fallbackFor(get("anthropic", "claude-fable-5-1"), prov("anthropic"), cfg)!), "anthropic/claude-opus-4-5"); // priciest allowed < $10 (opus is allowed)
});

test("config parse: lists, priceThreshold, and defaults on missing/invalid", () => {
  const { config, warning } = parseConfig("restrict:\n  - '*foo*'\nallow:\n  - \"*bar*\"\npriceThreshold: 2.5\n");
  assert.equal(warning, undefined);
  assert.deepEqual(config.restrict, ["*foo*"]);
  assert.deepEqual(config.allow, ["*bar*"]);
  assert.equal(config.priceThreshold, 2.5);
  assert.deepEqual(parseConfig(undefined).config, DEFAULT_CONFIG);
  for (const bad of ["restrict: [unclosed", "priceThreshold: lots", "autoTopTier: true"]) {
    const r = parseConfig(bad);
    assert.deepEqual(r.config, DEFAULT_CONFIG, bad);
    assert.ok(r.warning, bad);
  }
});
test("config parse: full-line and trailing comments are ignored", () => {
  const { config, warning } = parseConfig("# header\nrestrict:   # names\n  # a comment between items\n  - '*x*'  # trailing\npriceThreshold: 7 # usd\n");
  assert.equal(warning, undefined);
  assert.deepEqual(config.restrict, ["*x*"]);
  assert.equal(config.priceThreshold, 7);
});
test("shipped omp/model-guard.yml parses with no warning and matches the defaults", () => {
  const { config, warning } = parseConfig(readFileSync(new URL("../../omp/model-guard.yml", import.meta.url), "utf8"));
  assert.equal(warning, undefined);
  assert.deepEqual(config, DEFAULT_CONFIG);
});
test("approvals are per model key and can inherit from a parent", () => {
  const parent = new Approvals();
  parent.approve("anthropic/claude-fable-5-1");
  assert.ok(parent.has("anthropic/claude-fable-5-1"));
  assert.ok(!parent.has("openai-codex/gpt-6-astra"));
  const child = new Approvals(parent);
  assert.ok(child.has("anthropic/claude-fable-5-1"));
  child.approve("openai-codex/gpt-6-astra");
  assert.ok(!parent.has("openai-codex/gpt-6-astra"));
});
