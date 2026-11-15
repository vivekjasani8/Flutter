# Idle Miner Sim — Build Roadmap (M1–M9)

A virtual crypto-mining idle game for Android + iOS, built in Flutter.
**It is a game:** all coins, rigs and rankings are virtual; nothing is mined,
earned or paid out, and nothing is financial advice. That honesty rule is also
what keeps it inside Apple and Google review policy.

## How to use this file with Claude Code

Work one milestone at a time. For each, paste the **Prompt** into Claude Code,
let it build, then confirm the **Done when** line before moving on. Commit after
every milestone so each is reviewable.

- M0 (done): project scaffold, pure-Dart game engine, 18 unit tests, CI.
- Engine lives in `lib/engine/` with **no Flutter imports** — keep it that way so
  it stays unit-testable and can be reused server-side in M4.
- After each milestone: `flutter analyze` clean + `flutter test` green.

---

## M1 — Finish and test the game engine (week 1–2)

**Goal:** the engine is feature-complete and fully covered before any UI leans on it.

**Build:** extend `lib/engine/` — serialization (`toJson`/`fromJson` on `GameState`),
an "offline earnings since last sync" helper that returns the amount earned so the
UI can show a "while you were away" figure, and a balance simulation test that
verifies the payback targets (CPU ~17 min, Farm ~5.6 h). Add missing achievement
and boost-stacking tests.

**Prompt:**
```
Work in lib/engine only. Add GameState.toJson/fromJson (round-trip tested),
an offlineEarnings(state, now) helper returning coins earned since lastTick
(respecting the 8h cap), and a simulation test asserting each rig's payback
time matches the roadmap. Keep the engine free of Flutter imports. Run
flutter test and show results.
```

**Done when:** engine tests pass including JSON round-trip, offline-cap, clock-
rollback, boost-stacking and the payback simulation.

---

## M2 — Screens + local save (week 2–3)

**Goal:** a playable single-device game with no backend.

**Build:** add `flutter_riverpod` + `go_router` + `shared_preferences`. A
`GameController` (Riverpod notifier) owns the `GameState`, ticks it, and persists
to `shared_preferences` on change + on app pause. Build Mine, Shop (all 5 rigs +
upgrade), Stats (24h earnings via `fl_chart`) and Settings (shows the disclaimer)
screens with bottom-nav routing. Add a "While you were away" dialog on launch.

**Prompt:**
```
Add Riverpod, go_router, shared_preferences, fl_chart. Create a GameController
that owns GameState, ticks every second, and saves/loads from shared_preferences
(save on change and on app lifecycle pause). Build Mine, Shop, Stats, Settings
screens with bottom navigation, and a "while you were away" dialog on launch
using the engine's offlineEarnings helper. Keep all game math in lib/engine.
```

**Done when:** buying/upgrading rigs works; closing and reopening the app
restores coins, rigs and offline earnings; analyze clean, tests pass.

---

## M3 — Accounts + cloud save (week 4)

**Goal:** progress follows the player across devices; account deletion works.

**Build:** Firebase project (register Android + iOS apps, add `google-services.json`
and `GoogleService-Info.plist`). Add `firebase_core`, `firebase_auth`,
`cloud_firestore`. Sign in with Apple, Google, and guest. Mirror `GameState` to
Firestore under the user's uid; merge with local on login (take the higher
lifetime). In-app **account deletion** that removes the Firestore doc (Apple
requires this).

**You provide:** the Firebase project and the two config files.

**Prompt:**
```
Integrate Firebase Auth (Apple, Google, guest) and Firestore cloud save keyed
by uid. On login, merge cloud and local state keeping the higher lifetimeCoins.
Add a Settings action that deletes the account and its Firestore data. I'll add
google-services.json and GoogleService-Info.plist myself — tell me exactly
where they go.
```

**Done when:** the same progress appears on two devices; deleting the account
removes its cloud data.

---

## M4 — Leaderboard with server validation (week 5)

**Goal:** global rankings that cannot be cheated from the client.

**Build:** a Cloud Function (`functions/`, TypeScript) that receives a sync,
recomputes the **maximum possible** lifetime coins since the last sync (port the
engine's rate math), and writes the score. Firestore security rules **deny all
client writes** to the `scores` collection. Leaderboard screen: top 100 + the
player's own rank.

**Prompt:**
```
Add a Cloud Function validateSync that recomputes max possible lifetime coins
server-side and writes the leaderboard score; clients may never write scores
directly. Write Firestore rules denying client writes to /scores. Add a
Leaderboard screen (top 100 + my rank). Include an emulator test proving a
direct client score write is rejected.
```

**Done when:** emulator test shows a direct client write to `scores` is denied;
top 100 and own rank load.

---

## M5 — Streaks, achievements UI, notifications (week 5–6)

**Goal:** retention hooks.

**Build:** daily-streak claim screen (engine already has the logic), achievements
grid, and `flutter_local_notifications` reminders for "storage full" (offline cap
reached) and "streak at risk" (~20h since last claim).

**Prompt:**
```
Add a daily streak claim UI, an achievements grid bound to the engine, and local
notifications: one when the 8h offline cap is reached and one ~20h after the last
daily claim. Ask for notification permission at the right moment, not on launch.
```

**Done when:** streak resets after a missed day (tested); a reminder fires on a
real phone.

---

## M6 — Ads + purchases + consent (week 7)

**Goal:** honest monetization.

**Build:** AdMob (`google_mobile_ads`) rewarded video → grants a 30-min 2x boost,
plus a banner on the Shop. RevenueCat (`purchases_flutter`) for a one-time
**Remove Ads** and optional cosmetic packs — **no "hash rate" subscriptions.**
iOS App Tracking Transparency prompt (`app_tracking_transparency`) and Google's
UMP consent form before any ad tracking. A working **Restore Purchases** button.

**You provide:** AdMob + RevenueCat accounts and live IDs (build on test IDs first).

**Prompt:**
```
Integrate AdMob rewarded video (grants the engine's 30-min 2x boost) and a Shop
banner, using test IDs. Add RevenueCat for a one-time Remove Ads purchase and
cosmetic packs, with a Restore Purchases button. Add the iOS ATT prompt and the
UMP consent form before any ad tracking. No subscriptions. I'll swap in live IDs.
```

**Done when:** test ads show; a sandbox purchase + restore work; the consent
prompt appears in an EU test.

---

## M7 — Polish, performance, tuning (week 8)

**Goal:** ship quality.

**Build:** mining animation, haptics, accessibility labels/contrast, a
performance pass (const widgets, no jank on a mid-range phone), Crashlytics, and
move the economy constants to Firebase Remote Config so they tune without a
release.

**Prompt:**
```
Add Crashlytics, move the engine's economy constants to Firebase Remote Config
(with the current values as defaults), add accessibility labels and a mining
animation, and do a performance pass. Target zero analyzer warnings and smooth
scrolling on a mid-range Android phone.
```

**Done when:** smooth on a mid-range phone; zero analyzer warnings; beta bugs
closed.

---

## M8 — Release builds + store setup (week 9)

**Goal:** installable from the test tracks on both stores.

**Build:** CI release workflows for Android (signed AAB) and iOS (via a macOS
runner — Codemagic or GitHub Actions, since you're on Windows). Privacy policy
URL. Store listings with the disclaimer. Accurate App Privacy labels (Apple) and
Data Safety form (Google) matching what Firebase/AdMob/RevenueCat collect.

**You provide:** Apple Developer ($99/yr) + Play Console ($25 once); start the
Apple account early — the iOS build is the long pole.

**Prompt:**
```
Set up CI to produce a signed Android AAB and an iOS build via a macOS runner,
and push to Play internal testing and TestFlight. Draft the store listing text,
privacy policy, and the App Privacy / Data Safety answers from the SDKs we use.
Re-check current Apple and Google crypto/simulator policy wording first.
```

**Done when:** testers can install both builds from the store test tracks.

---

## M9 — Staged rollout + monitoring (week 10)

**Goal:** launch safely.

**Build:** a staged Play rollout (start small), a monitoring view for crash-free
sessions and day-1/day-7 retention, and a first hotfix window.

**Prompt:**
```
Set up a staged Play rollout starting at a low percentage, wire up a simple
monitoring dashboard for crash-free rate and retention, and prepare a hotfix
branch workflow. Tell me what metrics to watch in week one.
```

**Done when:** crash-free sessions stay high through the first week.

---

## Guardrails to repeat to Claude Code

- Keep `lib/engine` free of Flutter imports; all balance changes get a test.
- Never let the client write leaderboard scores — the Cloud Function does.
- No "withdraw / cash out / real USDT" wording anywhere; show the disclaimer on
  the store page, onboarding and Settings.
- Build on test ad/purchase IDs; swap live IDs only at M8.
- Commit per milestone; run analyze + test before calling a milestone done.
