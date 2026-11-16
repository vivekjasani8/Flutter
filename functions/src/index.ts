/**
 * Idle Miner Sim Cloud Functions (M4).
 *
 * - validateSync: the ONLY way a leaderboard score is written. Clients may
 *   never write /scores (see firestore.rules).
 * - cleanUpDeletedAccount: when an account is deleted, remove everything
 *   stored for it, including server-written data the client can't delete.
 *
 * Deploying needs the Blaze (pay-as-you-go) plan:
 *   firebase deploy --only functions --project idle-miner-sim
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getRemoteConfig } from "firebase-admin/remote-config";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as functionsV1 from "firebase-functions/v1";

import { DEFAULT_ECONOMY, Economy, parseEconomy } from "./economy.js";
import {
  leaderboardName,
  parseSaveClaim,
  ServerState,
  validateSync as validate,
} from "./validate.js";

initializeApp();

/** Same region as the Firestore database (Mumbai). */
const REGION = "asia-south1";

// --- balance, read from the same Remote Config parameter as the app ---

let cachedEconomy: { eco: Economy; at: number } | undefined;
const ECONOMY_TTL_MS = 10 * 60 * 1000;

async function loadEconomy(): Promise<Economy> {
  if (cachedEconomy && Date.now() - cachedEconomy.at < ECONOMY_TTL_MS) {
    return cachedEconomy.eco;
  }
  let eco = DEFAULT_ECONOMY;
  try {
    const template = await getRemoteConfig().getTemplate();
    const value = template.parameters["economy"]?.defaultValue;
    if (value && "value" in value) eco = parseEconomy(value.value);
  } catch (e) {
    logger.warn("Remote Config unavailable; using default balance", e);
  }
  cachedEconomy = { eco, at: Date.now() };
  return eco;
}

// --- functions ---

export const validateSync = onCall(
  { region: REGION, maxInstances: 10 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to join the leaderboard.");
    }
    let claim;
    try {
      claim = parseSaveClaim(request.data);
    } catch (e) {
      throw new HttpsError("invalid-argument", (e as Error).message);
    }

    const [eco, user] = await Promise.all([loadEconomy(), getAuth().getUser(uid)]);
    const accountCreatedMs = Date.parse(user.metadata.creationTime);
    const db = getFirestore();
    const stateRef = db.collection("serverState").doc(uid);
    const scoreRef = db.collection("scores").doc(uid);

    const result = await db.runTransaction(async (tx) => {
      const prev = (await tx.get(stateRef)).data() as ServerState | undefined;
      const r = validate({
        prev,
        claim,
        nowMs: Date.now(),
        accountCreatedMs,
        eco,
      });
      tx.set(stateRef, r.next);
      tx.set(scoreRef, {
        name: leaderboardName(claim.playerName, uid),
        score: r.score,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return r;
    });

    if (result.flagged) {
      logger.warn("Score claim reduced", {
        uid,
        claimed: claim.lifetimeCoins,
        accepted: result.score,
      });
    }

    // Rank = players strictly ahead + 1. Counted here so the rules can keep
    // client queries capped at 100 entries.
    const ahead = await db
      .collection("scores")
      .where("score", ">", result.score)
      .count()
      .get();
    return { score: result.score, rank: ahead.data().count + 1 };
  },
);

export const cleanUpDeletedAccount = functionsV1
  .region(REGION)
  .auth.user()
  .onDelete(async (user) => {
    const db = getFirestore();
    await Promise.all(
      ["users", "scores", "serverState"].map((c) =>
        db.collection(c).doc(user.uid).delete(),
      ),
    );
    logger.info("Deleted data for account", { uid: user.uid });
  });
