import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/brand_widgets.dart';
import '../../app/haptics.dart';
import '../../app/theme.dart';
import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';
import '../mine/hash_rate_card.dart';

/// Every rig with its level, output, payback time and a Buy/Upgrade button.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final brand = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: brand.accentTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: CoinAmount(
              s.coins,
              key: const ValueKey('shop-balance'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          // Buying raises this, so show it where the player buys.
          HashRateCard(state: s, compact: true),
          for (final rig in rigs) _RigCard(rig: rig, state: s),
        ],
      ),
    );
  }
}

class _RigCard extends ConsumerWidget {
  const _RigCard({required this.rig, required this.state});

  final RigDef rig;
  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brand = AppColors.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final level = state.rigs[rig.id] ?? 0;
    final cost = rigCost(rig.id, level);
    final affordable = canAfford(state, rig.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RigIcon(rig.id, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rig.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '+${formatNumber(rig.baseHash)} TH/s per level',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: brand.accent),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Lv $level',
                    key: ValueKey('level-${rig.id}'),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: muted?.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pays for itself in '
                    '${formatDuration(paybackSeconds(rig.id, level))}'
                    '${level > 0 ? '  ·  now ${formatNumber(rig.baseHash * level)} TH/s' : ''}',
                    style: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: ValueKey('buy-${rig.id}'),
                onPressed: affordable
                    ? () {
                        final bought = ref
                            .read(gameControllerProvider.notifier)
                            .buy(rig.id);
                        if (bought) Haptics.purchase(ref);
                      }
                    : null,
                // Shrinks rather than overflows with very large fonts.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(level == 0 ? 'Buy' : 'Upgrade'),
                      const SizedBox(width: 12),
                      Opacity(
                        opacity: affordable ? 1 : 0.5,
                        child: const CoinIcon(size: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(formatNumber(cost)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
