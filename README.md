# Idle Miner Sim

A virtual crypto-mining idle game for Android and iOS, built with Flutter.

> **This is a game.** All coins, rigs and rankings are virtual. No real
> cryptocurrency is mined, earned or paid out, and nothing here is financial advice.

## Status

Milestone **M1** — game engine feature-complete and fully tested (JSON save
format, offline earnings, payback balance simulation). See [ROADMAP.md](ROADMAP.md)
for the full plan (M0–M9).

## Project layout

```
lib/
  engine/      pure Dart game rules (no Flutter imports) — unit tested
  state/       app state (Riverpod added in M2)
  features/    mine/ shop/ stats/ settings/ screens
  main.dart    app entry
test/          engine unit tests
.github/workflows/ci.yml   analyze + test on every push
```

## Run it

```bash
flutter pub get
flutter analyze        # must be clean
flutter test           # engine unit tests must pass
flutter run            # opens on a connected device or emulator
```

If you cloned this before any native folders existed, generate them once with:

```bash
flutter create . --project-name idle_miner_sim --platforms=android,ios
```

(`flutter create` will not overwrite the existing `lib/`, `test/` or `pubspec.yaml`.)
