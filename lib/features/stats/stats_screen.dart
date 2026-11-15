import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';

/// Last-24-hours earnings chart plus lifetime totals.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);
    final history = earningsHistory(s, s.lastTick);
    final hasEarnings = history.any((h) => h.coins > 0);
    final rigsOwned = s.rigs.values.fold<int>(0, (sum, l) => sum + l);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Earnings, last 24 hours', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: hasEarnings
                ? _EarningsChart(history: history)
                : const Center(
                    child: Text('No earnings yet. Buy a rig to start mining.'),
                  ),
          ),
          const SizedBox(height: 24),
          _StatRow('Lifetime $coinName', formatNumber(s.lifetimeCoins)),
          _StatRow('Hash rate', '${formatNumber(totalHash(s))} TH/s'),
          _StatRow(
            'Income',
            '${formatNumber(baseCoinsPerSecond(s))} $coinName/s',
          ),
          _StatRow('Rig levels owned', '$rigsOwned'),
          _StatRow(
            'Achievements',
            '${s.achievements.length} / ${achievements.length}',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  // Not a ListTile: its trailing slot can't wrap, so a long value at large
  // font sizes would overflow. Here both sides share the width and wrap.
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: text.bodyLarge)),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                style: text.titleMedium,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsChart extends StatelessWidget {
  const _EarningsChart({required this.history});

  final List<({int hourStart, double coins})> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCoins =
        history.map((h) => h.coins).reduce((a, b) => a > b ? a : b);
    final last = history.length - 1;

    Widget bottomTitle(double value, TitleMeta meta) {
      final i = value.toInt();
      // Label every 6th hour plus the current one.
      if (i != last && (i % 6 != 0 || last - i < 3)) {
        return const SizedBox.shrink();
      }
      final hour =
          DateTime.fromMillisecondsSinceEpoch(history[i].hourStart).hour;
      return SideTitleWidget(
        meta: meta,
        child: Text(
          i == last ? 'now' : '${hour.toString().padLeft(2, '0')}:00',
          style: theme.textTheme.labelSmall,
        ),
      );
    }

    final total = history.fold<double>(0, (sum, h) => sum + h.coins);
    final best = history.reduce((a, b) => a.coins >= b.coins ? a : b);
    final bestHour = DateTime.fromMillisecondsSinceEpoch(best.hourStart).hour;

    // Screen readers get a one-line summary instead of 24 unlabeled bars.
    return Semantics(
      label: 'Earnings chart, last 24 hours. Total ${formatNumber(total)} '
          '$coinName. Best hour ${bestHour.toString().padLeft(2, '0')}:00 '
          'with ${formatNumber(best.coins)} $coinName.',
      excludeSemantics: true,
      child: RepaintBoundary(child: _chart(theme, maxCoins, bottomTitle)),
    );
  }

  Widget _chart(
    ThemeData theme,
    double maxCoins,
    Widget Function(double, TitleMeta) bottomTitle,
  ) {
    return BarChart(
      BarChartData(
        maxY: maxCoins * 1.15,
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: bottomTitle,
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              '${formatNumber(rod.toY)} $coinName',
              theme.textTheme.labelMedium ?? const TextStyle(),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < history.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: history[i].coins,
                  width: 8,
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
