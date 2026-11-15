import 'package:flutter/material.dart';

import '../engine/config.dart';
import '../engine/economy.dart';
import '../state/game_controller.dart';

/// "While you were away" summary. The coins are already in the balance; this
/// only tells the player what happened.
Future<void> showAwayDialog(BuildContext context, AwayReport report) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.nightlight_round),
        title: const Text('While you were away'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your rigs kept mining for '
              '${formatDuration(report.away.inSeconds.toDouble())}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '+${formatNumber(report.coins)} $coinName',
              key: const ValueKey('away-coins'),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: theme.colorScheme.primary),
              textAlign: TextAlign.center,
            ),
            if (report.capped) ...[
              const SizedBox(height: 16),
              Text(
                'Rigs only store '
                '${formatDuration(offlineCapSeconds.toDouble())} of mining. '
                'Check in sooner to keep every coin.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Collect'),
          ),
        ],
      );
    },
  );
}
