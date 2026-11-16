/**
 * Server copy of the game balance (port of lib/engine/config.dart).
 *
 * Keep in step with the Dart engine: same defaults, same Remote Config
 * override rules. The unit tests pin the defaults and the Dart test
 * `economy_config_test.dart` pins the Remote Config template, so a change on
 * one side fails a test until the other side matches.
 */

export interface Rig {
  id: string;
  baseHash: number; // TH/s per level
  baseCost: number; // SimCoin for level 1
}

export interface Economy {
  rigs: Rig[];
  costGrowth: number;
  coinsPerThSecond: number;
  offlineCapSeconds: number;
  boostMultiplier: number;
  boostDurationMs: number;
  startingCoins: number;
  streakRewardPerDay: number;
  streakRewardMaxDays: number;
}

export const DEFAULT_ECONOMY: Economy = Object.freeze({
  rigs: [
    { id: "cpu", baseHash: 1, baseCost: 50 },
    { id: "gpu", baseHash: 4, baseCost: 400 },
    { id: "asic_mini", baseHash: 14, baseCost: 3000 },
    { id: "asic_pro", baseHash: 55, baseCost: 25000 },
    { id: "farm", baseHash: 200, baseCost: 200000 },
  ],
  costGrowth: 1.15,
  coinsPerThSecond: 0.05,
  offlineCapSeconds: 8 * 3600,
  boostMultiplier: 2,
  boostDurationMs: 30 * 60 * 1000,
  startingCoins: 100,
  streakRewardPerDay: 100,
  streakRewardMaxDays: 7,
}) as Economy;

function num(v: unknown, fallback: number, min: number, max: number): number {
  return typeof v === "number" && Number.isFinite(v) && v >= min && v <= max
    ? v
    : fallback;
}

function whole(v: unknown, fallback: number, min: number, max: number): number {
  return typeof v === "number" && Number.isInteger(v) && v >= min && v <= max
    ? v
    : fallback;
}

/**
 * Apply Remote Config overrides exactly like EconomyConfig.fromJson in Dart:
 * missing, mistyped or out-of-range values keep the default, unknown keys
 * and rig ids are ignored.
 */
export function economyFromJson(
  json: unknown,
  base: Economy = DEFAULT_ECONOMY,
): Economy {
  if (typeof json !== "object" || json === null || Array.isArray(json)) {
    return base;
  }
  const j = json as Record<string, unknown>;
  const rigOverrides =
    typeof j.rigs === "object" && j.rigs !== null
      ? (j.rigs as Record<string, unknown>)
      : {};
  return {
    rigs: base.rigs.map((r) => {
      const o = rigOverrides[r.id];
      if (typeof o !== "object" || o === null) return r;
      const ov = o as Record<string, unknown>;
      return {
        id: r.id,
        baseCost: num(ov.baseCost, r.baseCost, 1, 1e12),
        baseHash: num(ov.baseHash, r.baseHash, 0.01, 1e9),
      };
    }),
    costGrowth: num(j.costGrowth, base.costGrowth, 1.01, 2),
    coinsPerThSecond: num(j.coinsPerThSecond, base.coinsPerThSecond, 0.0001, 10),
    offlineCapSeconds: whole(
      j.offlineCapSeconds, base.offlineCapSeconds, 3600, 48 * 3600),
    boostMultiplier: num(j.boostMultiplier, base.boostMultiplier, 1, 10),
    boostDurationMs: whole(
      j.boostDurationMs, base.boostDurationMs, 60 * 1000, 24 * 3600 * 1000),
    startingCoins: num(j.startingCoins, base.startingCoins, 0, 1e6),
    streakRewardPerDay: num(
      j.streakRewardPerDay, base.streakRewardPerDay, 1, 1e6),
    streakRewardMaxDays: whole(
      j.streakRewardMaxDays, base.streakRewardMaxDays, 1, 30),
  };
}

/** Like economyFromJson for a JSON string; unreadable input gives base. */
export function parseEconomy(
  source: string | undefined,
  base: Economy = DEFAULT_ECONOMY,
): Economy {
  if (!source) return base;
  try {
    return economyFromJson(JSON.parse(source), base);
  } catch {
    return base;
  }
}

/** Cost of the next level (currentLevel -> currentLevel + 1). */
export function rigCost(rig: Rig, currentLevel: number, eco: Economy): number {
  return Math.ceil(rig.baseCost * Math.pow(eco.costGrowth, currentLevel));
}

/** Total TH/s for these rig levels (unknown ids count for nothing). */
export function totalHash(levels: Record<string, number>, eco: Economy): number {
  let sum = 0;
  for (const r of eco.rigs) sum += r.baseHash * (levels[r.id] ?? 0);
  return sum;
}

/** SimCoin needed to have bought these levels from zero. */
export function spentOnRigs(levels: Record<string, number>, eco: Economy): number {
  let total = 0;
  for (const r of eco.rigs) {
    const level = levels[r.id] ?? 0;
    for (let l = 0; l < level; l++) total += rigCost(r, l, eco);
  }
  return total;
}
