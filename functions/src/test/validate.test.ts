import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  DEFAULT_ECONOMY as eco,
  parseEconomy,
  rigCost,
  spentOnRigs,
  totalHash,
} from "../economy.js";
import {
  GRACE_SECONDS,
  leaderboardName,
  maxEarnable,
  parseSaveClaim,
  SaveClaim,
  validateSync,
} from "../validate.js";

const HOUR = 3600 * 1000;
const t0 = 1_700_000_000_000;

function claim(over: Partial<SaveClaim> = {}): SaveClaim {
  return { lifetimeCoins: 0, coins: 100, rigs: {}, playerName: "", ...over };
}

describe("economy (must match lib/engine/config.dart)", () => {
  it("has the shipped defaults", () => {
    assert.equal(eco.costGrowth, 1.15);
    assert.equal(eco.coinsPerThSecond, 0.05);
    assert.equal(eco.offlineCapSeconds, 8 * 3600);
    assert.equal(eco.boostMultiplier, 2);
    assert.equal(eco.startingCoins, 100);
    assert.deepEqual(
      eco.rigs.map((r) => r.id),
      ["cpu", "gpu", "asic_mini", "asic_pro", "farm"],
    );
  });

  it("prices rigs like the app (ceil(base x growth^level))", () => {
    const cpu = eco.rigs[0];
    assert.equal(rigCost(cpu, 0, eco), 50);
    assert.equal(rigCost(cpu, 1, eco), 58);
    assert.equal(spentOnRigs({ cpu: 2 }, eco), 108);
    assert.equal(totalHash({ cpu: 5, gpu: 2 }, eco), 13);
  });

  it("applies Remote Config overrides with the same safety rules", () => {
    const tuned = parseEconomy(
      JSON.stringify({ costGrowth: 1.2, coinsPerThSecond: -1, rigs: { cpu: { baseCost: 40 }, nope: {} } }),
    );
    assert.equal(tuned.costGrowth, 1.2);
    assert.equal(tuned.coinsPerThSecond, 0.05, "out of range ignored");
    assert.equal(tuned.rigs[0].baseCost, 40);
    assert.equal(tuned.rigs.length, 5);
    assert.deepEqual(parseEconomy("not json"), eco);
  });
});

describe("validateSync", () => {
  it("accepts honest progress in full", () => {
    // 1 CPU rack for 1 hour earns 0.05 x 3600 = 180.
    const r = validateSync({
      prev: { validatedLifetime: 0, lastSyncAt: t0 },
      claim: claim({ lifetimeCoins: 180, coins: 230, rigs: { cpu: 1 } }),
      nowMs: t0 + HOUR,
      accountCreatedMs: t0,
      eco,
    });
    assert.equal(r.score, 180);
    assert.equal(r.flagged, false);
    assert.deepEqual(r.next, { validatedLifetime: 180, lastSyncAt: t0 + HOUR });
  });

  it("caps an impossible claim at the most that could be earned", () => {
    const r = validateSync({
      prev: { validatedLifetime: 1000, lastSyncAt: t0 },
      claim: claim({ lifetimeCoins: 1e12, coins: 1e12, rigs: { cpu: 1 } }),
      nowMs: t0 + HOUR,
      accountCreatedMs: t0,
      eco,
    });
    const most = 1000 + maxEarnable({ cpu: 1 }, 3600 + GRACE_SECONDS, eco);
    assert.equal(r.score, Math.floor(most));
    assert.equal(r.flagged, true);
  });

  it("uses the server clock: a phone clock moved forward gains nothing", () => {
    // The claim is what 10 days of offline time would pay, but the server
    // only saw 1 minute pass.
    const r = validateSync({
      prev: { validatedLifetime: 500, lastSyncAt: t0 },
      claim: claim({ lifetimeCoins: 500 + 1e6, rigs: { farm: 1 } , coins: 1e6 - 199_400 }),
      nowMs: t0 + 60_000,
      accountCreatedMs: t0,
      eco,
    });
    assert.ok(r.score < 500 + 10_000, `score ${r.score} should stay small`);
    assert.equal(r.flagged, true);
  });

  it("rejects rigs that were never paid for", () => {
    // 50 farms cost far more than the claimed lifetime earnings.
    const r = validateSync({
      prev: { validatedLifetime: 2000, lastSyncAt: t0 },
      claim: claim({ lifetimeCoins: 3000, coins: 0, rigs: { farm: 50 } }),
      nowMs: t0 + 24 * HOUR,
      accountCreatedMs: t0,
      eco,
    });
    assert.equal(r.score, 2000, "no progress counted");
    assert.equal(r.flagged, true);
  });

  it("first sync is bounded by the account's age", () => {
    const r = validateSync({
      prev: undefined,
      claim: claim({ lifetimeCoins: 1e9, coins: 1e9, rigs: { cpu: 1 } }),
      nowMs: t0 + 2 * HOUR,
      accountCreatedMs: t0,
      eco,
    });
    assert.ok(r.score <= maxEarnable({ cpu: 1 }, 2 * 3600 + GRACE_SECONDS, eco));
  });

  it("never lowers a validated score (e.g. after a progress reset)", () => {
    const r = validateSync({
      prev: { validatedLifetime: 9000, lastSyncAt: t0 },
      claim: claim({ lifetimeCoins: 0, coins: 100 }),
      nowMs: t0 + HOUR,
      accountCreatedMs: t0,
      eco,
    });
    assert.equal(r.score, 9000);
    assert.equal(r.flagged, false);
  });

  it("counts daily rewards that fit in the window", () => {
    // No rigs, but a day passed: a day-7 reward (700) is plausible.
    const r = validateSync({
      prev: { validatedLifetime: 0, lastSyncAt: t0 },
      claim: claim({ lifetimeCoins: 700, coins: 800 }),
      nowMs: t0 + 24 * HOUR,
      accountCreatedMs: t0,
      eco,
    });
    assert.equal(r.score, 700);
  });
});

describe("parseSaveClaim", () => {
  it("reads the app's save shape", () => {
    const c = parseSaveClaim({
      save: { lifetimeCoins: 10, coins: 5, rigs: { cpu: 2 }, playerName: "Ana", hourly: {} },
    });
    assert.deepEqual(c, { lifetimeCoins: 10, coins: 5, rigs: { cpu: 2 }, playerName: "Ana" });
  });

  it("rejects malformed input", () => {
    for (const bad of [
      undefined,
      {},
      { save: null },
      { save: { lifetimeCoins: -1, coins: 0 } },
      { save: { lifetimeCoins: Infinity, coins: 0 } },
      { save: { lifetimeCoins: 1, coins: "1" } },
      { save: { lifetimeCoins: 1, coins: 1, rigs: { cpu: 1.5 } } },
      { save: { lifetimeCoins: 1, coins: 1, rigs: { cpu: 1e9 } } },
    ]) {
      assert.throws(() => parseSaveClaim(bad), JSON.stringify(bad));
    }
  });
});

describe("leaderboardName", () => {
  it("cleans names and replaces the default", () => {
    assert.equal(leaderboardName("  Rig Runner ", "abcd123"), "Rig Runner");
    assert.equal(leaderboardName("Player", "abcd123"), "Miner ABCD");
    assert.equal(leaderboardName("", "xy9z"), "Miner XY9Z");
    assert.equal(leaderboardName("a\u0000b\u001fc", "u"), "abc");
    assert.equal(leaderboardName("x".repeat(50), "u").length, 20);
  });
});
