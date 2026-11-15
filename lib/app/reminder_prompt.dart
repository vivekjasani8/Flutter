import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Why we're offering reminders right now; picks the wording.
enum ReminderReason { streak, storage }

/// Offer reminders once, right after a moment where they obviously help
/// (first daily claim, or collecting offline earnings) instead of on launch.
/// Only if the player says yes do we trigger the OS permission dialog.
Future<void> maybeOfferReminders(
  BuildContext context,
  WidgetRef ref,
  ReminderReason reason,
) async {
  final reminders = ref.read(remindersProvider.notifier);
  if (!reminders.shouldOfferPrompt) return;
  await reminders.markPrompted();
  if (!context.mounted) return;

  final wantsThem = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: const Text('Want a reminder?'),
      content: Text(switch (reason) {
        ReminderReason.streak =>
          "We can remind you before your streak runs out, and when your rigs' "
              'storage is full.',
        ReminderReason.storage =>
          "We can remind you when your rigs' storage is full, and before your "
              'daily streak runs out.',
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const ValueKey('enable-reminders'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remind me'),
        ),
      ],
    ),
  );
  if (wantsThem != true) return;

  final granted = await reminders.enable();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(granted
        ? 'Reminders on. You can turn them off in Settings.'
        : 'Notifications are blocked. You can allow them in Settings.'),
  ));
}
