import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/economy.dart';
import 'providers.dart';
import 'reminder_scheduler.dart';
import 'reminders.dart';

/// Whether the player opted in to reminders (state), plus the scheduling that
/// follows from it. Reminders are opt-in: nothing is asked on launch.
class RemindersController extends Notifier<bool> {
  static const String enabledKey = 'reminders_enabled';

  /// Set once the soft "want reminders?" prompt has been shown, so it never
  /// nags twice. The Settings switch stays available either way.
  static const String promptedKey = 'reminders_prompted';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  ReminderScheduler get _scheduler => ref.read(reminderSchedulerProvider);

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(enabledKey) ?? false;

  /// True if the one-time prompt should still be offered.
  bool get shouldOfferPrompt =>
      !state && !(_prefs.getBool(promptedKey) ?? false);

  Future<void> markPrompted() => _prefs.setBool(promptedKey, true);

  /// Ask the OS for permission and turn reminders on if granted.
  Future<bool> enable() async {
    await markPrompted();
    final granted = await _scheduler.requestPermission();
    if (!granted) return false;
    state = true;
    await _prefs.setBool(enabledKey, true);
    return true;
  }

  Future<void> disable() async {
    state = false;
    await _prefs.setBool(enabledKey, false);
    await _scheduler.cancel(ReminderIds.planned);
  }

  /// App going to the background: schedule what is worth a reminder.
  Future<void> onAppPaused(GameState s, int now) async {
    await _scheduler.cancel(ReminderIds.planned);
    if (state) await _scheduler.schedule(planReminders(s, now));
  }

  /// App is open again: the player is here, so drop pending reminders. They
  /// are planned afresh on the next pause.
  Future<void> onAppResumed() => _scheduler.cancel(ReminderIds.planned);

  /// Debug helper: a reminder in [delay], to check notifications on a phone.
  Future<void> sendTest(int now,
      {Duration delay = const Duration(seconds: 10)}) {
    return _scheduler.schedule([
      Reminder(
        id: ReminderIds.test,
        at: now + delay.inMilliseconds,
        title: 'Test reminder',
        body: 'Reminders are working.',
      ),
    ]);
  }
}
