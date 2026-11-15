import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/economy.dart';
import 'game_controller.dart';
import 'game_storage.dart';
import 'reminder_scheduler.dart';
import 'reminders_controller.dart';

/// Loaded once in `main()` and injected with `overrideWithValue`, so the rest
/// of the app can read preferences synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'Override sharedPreferencesProvider in main() or in the test.'),
);

/// Current time in ms since epoch. Tests override it with a fake clock.
typedef Clock = int Function();

final clockProvider =
    Provider<Clock>((ref) => () => DateTime.now().millisecondsSinceEpoch);

final gameStorageProvider = Provider<GameStorage>(
  (ref) => GameStorage(ref.watch(sharedPreferencesProvider)),
);

/// The player's live game. Watch it to rebuild every tick; use `.notifier`
/// for actions such as buying rigs.
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Created (and the plugin initialised) in `main()`; tests inject a fake.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => throw UnimplementedError(
      'Override reminderSchedulerProvider in main() or in the test.'),
);

/// Whether reminders are on. Use `.notifier` to enable/disable and schedule.
final remindersProvider =
    NotifierProvider<RemindersController, bool>(RemindersController.new);
