import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/app/app.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/cloud/cloud_auth.dart';
import 'package:idle_miner_sim/state/cloud/cloud_store.dart';
import 'package:idle_miner_sim/state/game_storage.dart';
import 'package:idle_miner_sim/state/onboarding_controller.dart';
import 'package:idle_miner_sim/state/providers.dart';
import 'package:idle_miner_sim/state/reminder_scheduler.dart';
import 'package:idle_miner_sim/state/reminders.dart';
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

/// Records reminders instead of talking to the OS.
class FakeReminderScheduler implements ReminderScheduler {
  /// What the OS permission dialog "answers".
  bool grant = true;
  int permissionRequests = 0;

  /// Currently pending reminders by id.
  final Map<int, Reminder> pending = {};

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    for (final r in reminders) {
      pending[r.id] = r;
    }
  }

  @override
  Future<void> cancel(List<int> ids) async {
    ids.forEach(pending.remove);
  }
}

/// Cloud is "unavailable" unless a test passes fakes, exactly like a device
/// where Firebase didn't start.
List<Override> appOverrides(
  SharedPreferences prefs,
  FakeClock clock, {
  ReminderScheduler? reminders,
  CloudAuth? cloudAuth,
  CloudSaveStore? cloudStore,
}) =>
    [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock.call),
      reminderSchedulerProvider
          .overrideWithValue(reminders ?? FakeReminderScheduler()),
      if (cloudAuth != null) cloudAuthProvider.overrideWithValue(cloudAuth),
      if (cloudStore != null) cloudStoreProvider.overrideWithValue(cloudStore),
    ];

/// A provider container for controller tests. Disposed after the test unless
/// [autoDispose] is false (then the test disposes it, e.g. to "close the app").
ProviderContainer gameContainer(
  SharedPreferences prefs,
  FakeClock clock, {
  bool autoDispose = true,
  ReminderScheduler? reminders,
  CloudAuth? cloudAuth,
  CloudSaveStore? cloudStore,
}) {
  final c = ProviderContainer(
    overrides: appOverrides(prefs, clock,
        reminders: reminders, cloudAuth: cloudAuth, cloudStore: cloudStore),
  );
  if (autoDispose) addTearDown(c.dispose);
  return c;
}

/// Launch the full app with a fake clock and the given saved data.
///
/// By default the OS "remove animations" setting is on, so the endless
/// mining spinner doesn't keep `pumpAndSettle` waiting forever. Pass
/// `animations: true` to test the animations themselves.
Future<SharedPreferences> pumpApp(
  WidgetTester tester,
  FakeClock clock, {
  Map<String, Object> saved = const {},
  ReminderScheduler? reminders,
  bool animations = false,
  bool settle = true,
  bool onboarded = true,
  CloudAuth? cloudAuth,
  CloudSaveStore? cloudStore,
}) async {
  if (!animations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  // Most tests are about the game, so skip the first-launch intro unless a
  // test asks for it.
  final prefs = await mockPrefs({
    if (onboarded) OnboardingController.key: true,
    ...saved,
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(prefs, clock,
          reminders: reminders, cloudAuth: cloudAuth, cloudStore: cloudStore),
      child: const IdleMinerApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return prefs;
}

ProviderContainer _appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(IdleMinerApp)));

/// The live game state inside a pumped app.
GameState liveGame(WidgetTester tester) =>
    _appContainer(tester).read(gameControllerProvider);

/// Whether reminders are switched on inside a pumped app.
bool remindersOn(WidgetTester tester) =>
    _appContainer(tester).read(remindersProvider);

/// The bottom-navigation tab with this label.
Finder navTab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(navTab(label));
  await tester.pumpAndSettle();
}

/// Drive the real lifecycle sequence (resumed → inactive → hidden → paused).
Future<void> sendToBackground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

/// And back again (paused → hidden → inactive → resumed).
Future<void> bringToForeground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}

/// Background the app, let [away] pass on [clock], and bring it back.
Future<void> backgroundFor(
  WidgetTester tester,
  FakeClock clock,
  Duration away,
) async {
  await sendToBackground(tester);
  clock.advance(away);
  await bringToForeground(tester);
}
