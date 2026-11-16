import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/brand_widgets.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';
import 'hash_rate_card.dart';
import 'mining_animation.dart';

/// Home tab: live balance, mining rate and the rigs the player owns.
class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);
    final brand = AppColors.of(context);
    final now = s.lastTick;
    final owned = [
      for (final r in rigs)
        if ((s.rigs[r.id] ?? 0) > 0) r,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinIcon(size: 26),
            SizedBox(width: 10),
            Text('Idle Miner'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(child: MiningAnimation(hashRate: totalHash(s), size: 136)),
          const SizedBox(height: 20),
          // One screen-reader node for "SimCoin balance, 1.2K" instead of
          // several, and not a live region: it changes every second.
          Semantics(
            label: '$coinName balance',
            value: formatNumber(s.coins),
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  'Balance',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon(size: 34),
                    const SizedBox(width: 10),
                    Flexible(
                      child: RollingNumber(
                        key: const ValueKey('balance'),
                        value: s.coins,
                        style: theme.textTheme.displayMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          HashRateCard(state: s),
          if (isBoosted(s, now)) ...[
            const SizedBox(height: 12),
            Center(
              child: Chip(
                avatar: Icon(Icons.bolt, size: 18, color: brand.accent),
                label: Text(
                  '${boostMultiplier.toStringAsFixed(0)}x boost · '
                  '${formatDuration((s.boostUntil - now) / 1000)} left',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Your rigs', style: theme.textTheme.titleMedium),
              ),
              if (owned.isNotEmpty)
                TextButton.icon(
                  onPressed: () => context.go(Routes.shop),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Get more'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (owned.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const RigIcon('cpu', size: 52),
                    const SizedBox(height: 12),
                    Text('No rigs yet', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Buy a CPU Rack in the Shop to start mining.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(Routes.shop),
                      child: const Text('Go to Shop'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < owned.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 72, endIndent: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: RigIcon(owned[i].id),
                      title: Text(owned[i].name,
                          style: theme.textTheme.titleSmall),
                      subtitle: Text('Lv ${s.rigs[owned[i].id]}'),
                      trailing: Text(
                        '${formatNumber(owned[i].baseHash * (s.rigs[owned[i].id] ?? 0))} TH/s',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: brand.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'A game. Coins are virtual, never real money.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
