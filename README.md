# Idle Miner Sim

A virtual crypto-mining idle game for Android and iOS, built with Flutter.

> **This is a game.** All coins, rigs and rankings are virtual. No real
> cryptocurrency is mined, earned or paid out, and nothing here is financial advice.

## Status

Done: M0–M2, **M5** and the offline part of **M7**: first-launch intro with
the disclaimer; Mine, Shop, Rewards (daily streak + achievements), Stats and
Settings; local save; "while you were away"; opt-in reminders; mining
animation, haptics, accessibility and a performance pass.

**M3 (accounts + cloud save) is in code**: Firebase project `idle-miner-sim`,
guest sign-in by default, Google sign-in, cloud save that keeps the save with
more progress, and account deletion. Device testing and deploying
`firestore.rules` are still pending. M4 leaderboard, M6 ads/purchases and
M7's Crashlytics + Remote Config come later. See
[ROADMAP.md](ROADMAP.md) for the full plan and
[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for what must happen before a
store release.

## Project layout

```
lib/
  engine/      pure Dart game rules (no Flutter imports) — unit tested
  state/       GameController (Riverpod), save/load, reminder planning,
               cloud/ (auth + Firestore sync behind interfaces)
  app/         app root, go_router routes, bottom-nav shell, dialogs
  features/    onboarding/ mine/ shop/ rewards/ stats/ settings/ screens
  main.dart    app entry (loads preferences, starts ProviderScope)
test/          engine, state and widget tests (support/ has shared helpers)
.github/workflows/ci.yml   format + analyze + test on every push
```

## Run it

```bash
flutter pub get
dart format .          # CI fails on unformatted code
flutter analyze        # must be clean
flutter test           # all tests must pass
flutter run            # opens on a connected device or emulator
```

If you cloned this before any native folders existed, generate them once with:

```bash
flutter create . --project-name idle_miner_sim --platforms=android,ios
```

(`flutter create` will not overwrite the existing `lib/`, `test/` or `pubspec.yaml`.)
