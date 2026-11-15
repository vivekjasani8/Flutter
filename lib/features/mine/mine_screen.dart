import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';
import 'mining_animation.dart';

/// Home tab: live balance, mining rate and the rigs the player owns.
class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);
    final now = s.lastTick;
    final owned = [
      for (final r in rigs)
        if ((s.rigs[r.id] ?? 0) > 0) r,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Idle Miner Sim')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: MiningAnimation(hashRate: totalHash(s))),
          const SizedBox(height: 16),
          // One screen-reader node for "SimCoin balance, 1.2K" instead of
          // two, and not a live region: it changes every second.
          Semantics(
            label: '$coinName balance',
            value: formatNumber(s.coins),
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  '$coinName balance',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                RollingNumber(
                  key: const ValueKey('balance'),
                  value: s.coins,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatNumber(totalHash(s))} TH/s  ·  '
            '${formatNumber(baseCoinsPerSecond(s))} $coinName/s',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (isBoosted(s, now)) ...[
            const SizedBox(height: 12),
            Center(
              child: Chip(
                avatar: const Icon(Icons.bolt, size: 18),
                label: Text(
                  '${boostMultiplier.toStringAsFixed(0)}x boost · '
                  '${formatDuration((s.boostUntil - now) / 1000)} left',
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text('Your rigs', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (owned.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'No rigs yet. Buy a CPU Rack in the Shop to start mining.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.go(Routes.shop),
                      child: const Text('Go to Shop'),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final r in owned)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.memory),
                  title: Text(r.name),
                  subtitle: Text('Lv ${s.rigs[r.id]}'),
                  trailing: Text(
                    '${formatNumber(r.baseHash * (s.rigs[r.id] ?? 0))} TH/s',
                  ),
                ),
              ),
          const SizedBox(height: 24),
          Text(
            appDisclaimer,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
