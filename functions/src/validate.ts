/**
 * Server-side score validation: the leaderboard never trusts the client.
 *
 * The client sends its whole save. Using the *server* clock, we compute the
 * most lifetime coins the player could possibly have earned since we last
 * validated them, and the score is the smaller of that and what they claim.
 * This is a generous upper bound (as if boosted the whole time, at their
 * current hash rate, plus every daily reward that could fit), so honest
 * players are never under-counted, while a modified client or a moved phone
 * clock gains at most what real play could have earned.
 */
import { Economy, spentOnRigs, totalHash } from "./economy.js";

/** What we keep per player, server-only (clients can't read or write it). */
export interface ServerState {
  /** Best lifetime coins we have accepted so far. */
  validatedLifetime: number;
  /** Server time (ms) of the last accepted sync. */
  lastSyncAt: number;
}

/** The parts of the client save the check needs. */
export interface SaveClaim {
  lifetimeCoins: number;
  coins: number;
  rigs: Record<string, number>;
  playerName: string;
}

export interface ValidationResult {
  /** Leaderboard score: whole SimCoin of validated lifetime earnings. */
  score: number;
  next: ServerState;
  /** True when the claim was cut down or rejected (worth logging). */
  flagged: boolean;
}

/** Slack for network delay and the client's own sync timing. */
export const GRACE_SECONDS = 120;

/** Accept the save shape the app sends; throw on anything else. */
export function parseSaveClaim(data: unknown): SaveClaim {
  const save = (data as { save?: unknown } | null)?.save;
  if (typeof save !== "object" || save === null) {
    throw new Error("Missing save.");
  }
  const s = save as Record<string, unknown>;
  const finite = (v: unknown) =>
    typeof v === "number" && Number.isFinite(v) && v >= 0;
  if (!finite(s.lifetimeCoins) || !finite(s.coins)) {
    throw new Error("Bad coin values.");
  }
  const rigs: Record<string, number> = {};
  if (typeof s.rigs === "object" && s.rigs !== null) {
    for (const [id, level] of Object.entries(s.rigs as object)) {
      if (!Number.isInteger(level) || (level as number) < 0 ||
          (level as number) > 10000) {
        throw new Error(`Bad level for ${id}.`);
      }
      rigs[id] = level as number;
    }
  }
  return {
    lifetimeCoins: s.lifetimeCoins as number,
    coins: s.coins as number,
    rigs,
    playerName: typeof s.playerName === "string" ? s.playerName : "",
  };
}

/** Most lifetime coins that could be earned in [seconds] with these rigs. */
export function maxEarnable(
  rigs: Record<string, number>,
  seconds: number,
  eco: Economy,
): number {
  // Rigs can only be bought, never sold, so today's hash rate is the
  // highest it has been during the window: use it for all of it, boosted.
  const rate = totalHash(rigs, eco) * eco.coinsPerThSecond;
  const mining = rate * eco.boostMultiplier * seconds;
  // At most one daily claim per UTC day the window touches.
  const claims = Math.floor(seconds / 86400) + 2;
  const rewards = claims * eco.streakRewardPerDay * eco.streakRewardMaxDays;
  return mining + rewards;
}

export function validateSync(args: {
  prev: ServerState | undefined;
  claim: SaveClaim;
  nowMs: number;
  /** When the account was created (bounds the very first sync). */
  accountCreatedMs: number;
  eco: Economy;
}): ValidationResult {
  const { prev, claim, nowMs, accountCreatedMs, eco } = args;
  const base = prev?.validatedLifetime ?? 0;
  const sinceMs = nowMs - (prev?.lastSyncAt ?? accountCreatedMs);
  const seconds = Math.max(0, sinceMs / 1000) + GRACE_SECONDS;
  const allowed = base + maxEarnable(claim.rigs, seconds, eco);

  // Owning rigs means having paid for them: balance + everything spent can't
  // exceed the starting coins plus everything ever earned.
  const paidFor =
    spentOnRigs(claim.rigs, eco) + claim.coins <=
    eco.startingCoins + claim.lifetimeCoins + 1;

  let score: number;
  let flagged: boolean;
  if (!paidFor) {
    score = base; // inconsistent save: no progress counted
    flagged = true;
  } else {
    const capped = Math.min(claim.lifetimeCoins, allowed);
    flagged = claim.lifetimeCoins > allowed;
    // The best validated score never goes down (e.g. after a progress reset).
    score = Math.max(base, capped);
  }
  score = Math.floor(score);
  return {
    score,
    next: { validatedLifetime: score, lastSyncAt: nowMs },
    flagged,
  };
}

/**
 * Name shown on the leaderboard: trimmed, at most 20 characters, no control
 * characters; the default "Player" (or nothing) becomes "Miner XXXX" so the
 * board isn't a wall of identical names.
 */
export function leaderboardName(raw: string, uid: string): string {
  const clean = raw.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, 20);
  if (clean === "" || clean.toLowerCase() === "player") {
    return `Miner ${uid.slice(0, 4).toUpperCase()}`;
  }
  return clean;
}
