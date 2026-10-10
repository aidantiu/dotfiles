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
