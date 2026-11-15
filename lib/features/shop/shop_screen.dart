import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';

/// Every rig with its level, output, payback time and a Buy/Upgrade button.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${formatNumber(s.coins)} $coinName',
                key: const ValueKey('shop-balance'),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                Expanded(
                  child: Text(rig.name, style: theme.textTheme.titleMedium),
                ),
                Text(
                  'Lv $level',
                  key: ValueKey('level-${rig.id}'),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '+${formatNumber(rig.baseHash)} TH/s per level'
              '${level > 0 ? '  ·  now ${formatNumber(rig.baseHash * level)} TH/s' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              'Pays for itself in '
              '${formatDuration(paybackSeconds(rig.id, level))}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('buy-${rig.id}'),
                onPressed: affordable
                    ? () =>
                        ref.read(gameControllerProvider.notifier).buy(rig.id)
                    : null,
                child: Text(
                  '${level == 0 ? 'Buy' : 'Upgrade'}  ·  '
                  '${formatNumber(cost)} $coinName',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
