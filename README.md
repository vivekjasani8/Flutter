# Idle Miner Sim

A virtual crypto-mining idle game for Android and iOS, built with Flutter.

> **This is a game.** All coins, rigs and rankings are virtual. No real
> cryptocurrency is mined, earned or paid out, and nothing here is financial advice.

## Status

Milestone **M2** — playable single-device game: Mine, Shop, Stats and Settings
screens, local save, and a "while you were away" summary. No backend yet. See
[ROADMAP.md](ROADMAP.md) for the full plan (M0–M9).

## Project layout

```
lib/
  engine/      pure Dart game rules (no Flutter imports) — unit tested
  state/       GameController (Riverpod) + shared_preferences save/load
  app/         app root, go_router routes, bottom-nav shell, away dialog
  features/    mine/ shop/ stats/ settings/ screens
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
