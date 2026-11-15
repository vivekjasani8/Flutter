import 'package:flutter/material.dart';

import '../../engine/config.dart';
import '../../engine/economy.dart';

/// Prominent "Total hash rate" and income readout. Used on Mine, and in a
/// compact form at the top of the Shop where buying changes it.
class HashRateCard extends StatelessWidget {
  const HashRateCard({super.key, required this.state, this.compact = false});

  final GameState state;

  /// Shop variant: hash rate only, one line.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hash = totalHash(state);
    final perSecond = baseCoinsPerSecond(state);

    final hashTile = _Stat(
      icon: Icons.speed,
      label: 'Total hash rate',
      value: '${formatNumber(hash)} TH/s',
      valueKey: const ValueKey('total-hash'),
      valueStyle:
          (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall)
              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: compact
            ? hashTile
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: hashTile),
                    const VerticalDivider(width: 24),
                    Expanded(
                      child: _Stat(
                        icon: Icons.trending_up,
                        label: 'Income',
                        value: '${formatNumber(perSecond)} $coinName/s',
                        valueKey: const ValueKey('income'),
                        valueStyle: theme.textTheme.titleMedium,
                        detail: '${formatNumber(perSecond * 3600)} per hour',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
    this.valueStyle,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key valueKey;
  final TextStyle? valueStyle;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // One screen-reader node: "Total hash rate, 7 TH/s".
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, key: valueKey, style: valueStyle),
          if (detail != null) Text(detail!, style: muted),
        ],
      ),
    );
  }
}
