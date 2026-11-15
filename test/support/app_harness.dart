import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/app/app.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/game_storage.dart';
import 'package:idle_miner_sim/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A clock the test moves by hand. Pass `clock.call` as the app's clock.
class FakeClock {
  FakeClock(this.now);

  int now;

  int call() => now;

  void advance(Duration d) => now += d.inMilliseconds;
}

/// Fresh in-memory shared_preferences, optionally pre-filled ("on disk").
Future<SharedPreferences> mockPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Preferences contents as if [s] had been saved by an earlier app session.
Map<String, Object> savedGame(GameState s) =>
    {GameStorage.key: jsonEncode(s.toJson())};

/// The game as currently stored in [prefs].
GameState? storedGame(SharedPreferences prefs) => GameStorage(prefs).load();

List<Override> appOverrides(SharedPreferences prefs, FakeClock clock) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock.call),
    ];

/// A provider container for controller tests. Disposed after the test unless
/// [autoDispose] is false (then the test disposes it, e.g. to "close the app").
ProviderContainer gameContainer(
  SharedPreferences prefs,
  FakeClock clock, {
  bool autoDispose = true,
}) {
  final c = ProviderContainer(overrides: appOverrides(prefs, clock));
  if (autoDispose) addTearDown(c.dispose);
  return c;
}

/// Launch the full app with a fake clock and the given saved data.
Future<SharedPreferences> pumpApp(
  WidgetTester tester,
  FakeClock clock, {
  Map<String, Object> saved = const {},
}) async {
  final prefs = await mockPrefs(saved);
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs, clock),
      child: const IdleMinerApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

/// The live game state inside a pumped app.
GameState liveGame(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(IdleMinerApp)),
    ).read(gameControllerProvider);
