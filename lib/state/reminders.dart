import '../engine/config.dart';
import '../engine/economy.dart';

/// A notification to show at a fixed moment.
class Reminder {
  const Reminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Stable per kind, so rescheduling replaces rather than duplicates.
  final int id;

  /// When to show it, ms since epoch.
  final int at;
  final String title;
  final String body;
}

abstract final class ReminderIds {
  static const int storageFull = 1;
  static const int streakAtRisk = 2;
  static const int test = 99;

  /// The reminders the game plans itself (the test one is left alone).
  static const List<int> planned = [storageFull, streakAtRisk];
}

/// How long before the streak breaks to warn the player.
const Duration streakWarning = Duration(hours: 4);

/// The reminders worth scheduling when the app goes to the background with
/// state [s] at [now]:
///
/// - **Storage full** when the rigs have filled the offline cap (only if the
///   player has any hash rate).
/// - **Streak at risk** [streakWarning] before the streak would break (only
///   if there is a streak to lose). The claim is already open by then.
///
/// Pure function: no plugin calls, so it is unit-tested directly.
List<Reminder> planReminders(GameState s, int now) {
  final out = <Reminder>[];

  if (totalHash(s) > 0) {
    final at = storageFullAt(s);
    if (at > now) {
      final stored = offlineEarnings(s, at);
      out.add(Reminder(
        id: ReminderIds.storageFull,
        at: at,
        title: 'Storage full',
        body: 'Your rigs have stored '
            '${formatDuration(offlineCapSeconds.toDouble())} of mining '
            '(+${formatNumber(stored)} $coinName). Open the game to keep '
            'them running.',
      ));
    }
  }

  final deadline = streakDeadline(s);
  if (deadline != null && s.streak > 0) {
    final at = deadline - streakWarning.inMilliseconds;
    if (at > now) {
      out.add(Reminder(
        id: ReminderIds.streakAtRisk,
        at: at,
        title: 'Your ${s.streak}-day streak is at risk',
        body: "Claim today's reward in the next "
            '${formatDuration(streakWarning.inSeconds.toDouble())} '
            'to keep it going.',
      ));
    }
  }
  return out;
}
