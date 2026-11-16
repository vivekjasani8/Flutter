/**
 * Firestore security rules, tested against the real rules engine in the
 * local emulator (no Firebase project or internet needed):
 *
 *   npm run test:rules
 *
 * M4 "done when": a direct client write to /scores is rejected.
 */
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from "firebase/firestore";
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";

let env: RulesTestEnvironment;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-idle-miner",
    firestore: {
      rules: readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Data the Cloud Function would have written (rules bypassed).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "scores/alice"), { name: "Alice", score: 500 });
    await setDoc(doc(db, "scores/bob"), { name: "Bob", score: 900 });
    await setDoc(doc(db, "serverState/alice"), {
      validatedLifetime: 500,
      lastSyncAt: 1,
    });
  });
});

const alice = () => env.authenticatedContext("alice").firestore();
const bob = () => env.authenticatedContext("bob").firestore();
const stranger = () => env.unauthenticatedContext().firestore();

function validSave() {
  return {
    save: { coins: 10, lifetimeCoins: 20, rigs: { cpu: 1 } },
    lifetimeCoins: 20,
    schemaVersion: 1,
    updatedAt: serverTimestamp(),
    platform: "android",
  };
}

describe("leaderboard /scores", () => {
  it("rejects a direct client write to scores (M4 done-when)", async () => {
    await assertFails(
      setDoc(doc(alice(), "scores/alice"), { name: "Alice", score: 1e12 }),
    );
  });

  it("rejects editing or deleting even your own score", async () => {
    await assertFails(updateDoc(doc(alice(), "scores/alice"), { score: 1e12 }));
    await assertFails(deleteDoc(doc(alice(), "scores/alice")));
    await assertFails(setDoc(doc(alice(), "scores/mallory"), { score: 1 }));
  });

  it("lets signed-in players read the top 100", async () => {
    const top = query(
      collection(alice(), "scores"),
      orderBy("score", "desc"),
      limit(100),
    );
    const snap = await assertSucceeds(getDocs(top));
    if (snap.docs.map((d) => d.id).join() !== "bob,alice") {
      throw new Error("unexpected order");
    }
    await assertSucceeds(getDoc(doc(alice(), "scores/bob")));
  });

  it("refuses bigger or unlimited queries", async () => {
    await assertFails(getDocs(query(collection(alice(), "scores"), limit(101))));
    await assertFails(getDocs(collection(alice(), "scores")));
  });

  it("is hidden from signed-out visitors", async () => {
    await assertFails(
      getDocs(query(collection(stranger(), "scores"), limit(10))),
    );
  });
});

describe("server-only /serverState", () => {
  it("can't be read or written by anyone, owner included", async () => {
    await assertFails(getDoc(doc(alice(), "serverState/alice")));
    await assertFails(
      setDoc(doc(alice(), "serverState/alice"), {
        validatedLifetime: 1e12,
        lastSyncAt: 0,
      }),
    );
  });
});

describe("cloud saves /users (M3)", () => {
  it("owner can write, read and delete a valid save", async () => {
    await assertSucceeds(setDoc(doc(alice(), "users/alice"), validSave()));
    await assertSucceeds(getDoc(doc(alice(), "users/alice")));
    await assertSucceeds(deleteDoc(doc(alice(), "users/alice")));
  });

  it("nobody else can read, write or delete it", async () => {
    await assertSucceeds(setDoc(doc(alice(), "users/alice"), validSave()));
    await assertFails(getDoc(doc(bob(), "users/alice")));
    await assertFails(setDoc(doc(bob(), "users/alice"), validSave()));
    await assertFails(deleteDoc(doc(bob(), "users/alice")));
    await assertFails(getDoc(doc(stranger(), "users/alice")));
  });

  it("rejects saves with the wrong shape", async () => {
    const ref = doc(alice(), "users/alice");
    await assertFails(setDoc(ref, { ...validSave(), extra: true }));
    await assertFails(setDoc(ref, { ...validSave(), lifetimeCoins: -5 }));
    await assertFails(setDoc(ref, { ...validSave(), save: "nope" }));
    await assertFails(
      setDoc(ref, { ...validSave(), updatedAt: Timestamp.fromMillis(0) }),
    );
    const missing: Record<string, unknown> = { ...validSave() };
    delete missing.schemaVersion;
    await assertFails(setDoc(ref, missing));
  });

  it("anything else in the database is closed", async () => {
    await assertFails(setDoc(doc(alice(), "anything/else"), { a: 1 }));
    await assertFails(getDoc(doc(alice(), "anything/else")));
  });
});
