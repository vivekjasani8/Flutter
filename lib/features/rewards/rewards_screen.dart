import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/haptics.dart';
import '../../app/reminder_prompt.dart';
import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';

/// Daily streak claim and the achievements grid.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);
    final unlocked = s.achievements.toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DailyRewardCard(state: s),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Achievements', style: theme.textTheme.titleMedium),
              ),
              Text(
                '${unlocked.length} / ${achievements.length}',
                key: const ValueKey('achievement-count'),
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Two per row, each row as tall as its tallest tile, so tiles grow
          // with large fonts instead of overflowing a fixed-size grid cell.
          for (var i = 0; i < achievements.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in achievements.skip(i).take(2)) ...[
                      if (a != achievements[i]) const SizedBox(width: 8),
                      Expanded(
                        child: _AchievementTile(
                          def: a,
                          unlocked: unlocked.contains(a.id),
                        ),
                      ),
                    ],
                    if (i + 1 >= achievements.length) ...[
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyRewardCard extends ConsumerWidget {
  const _DailyRewardCard({required this.state});

  final GameState state;

  /// Rewards stop growing after this day (tunable via Remote Config).
  static int get _maxDay => economy.streakRewardMaxDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = state.lastTick;
    final canClaim = canClaimDaily(state, now);
    final streak = activeStreak(state, now);
    final nextDay = nextClaimStreak(state, now);
    // Which of the 7 day chips is "today's" reward.
    final highlight = (canClaim ? nextDay : streak).clamp(1, _maxDay);
    final resetLocal =
        DateTime.fromMillisecondsSinceEpoch(now + msUntilNextDay(now));
    final resetTime = '${resetLocal.hour.toString().padLeft(2, '0')}:'
        '${resetLocal.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department,
                    color: streak > 0
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    streak == 0 ? 'No streak yet' : '$streak-day streak',
                    key: const ValueKey('streak'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var day = 1; day <= _maxDay; day++)
                  Expanded(
                    child: _DayChip(
                      day: day,
                      reward: streakReward(day),
                      done: day < highlight || (!canClaim && day == highlight),
                      current: day == highlight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('claim-daily'),
              icon: Icon(canClaim ? Icons.redeem : Icons.schedule),
              onPressed: canClaim ? () => _claim(context, ref) : null,
              label: Text(
                canClaim
                    ? 'Claim +${formatNumber(streakReward(nextDay))} $coinName'
                    : 'Next reward in '
                        '${formatDuration(msUntilNextDay(now) / 1000)}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A new reward unlocks every day at $resetTime. Miss a day and '
              'the streak starts again from day 1.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final paid = ref.read(gameControllerProvider.notifier).claimDaily();
    if (paid == null) return;
    Haptics.reward(ref);
    final day = ref.read(gameControllerProvider).streak;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('+${formatNumber(paid)} $coinName · day $day streak'),
    ));
    await maybeOfferReminders(context, ref, ReminderReason.streak);
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.reward,
    required this.done,
    required this.current,
  });

  final int day;
  final double reward;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = done
        ? 'claimed'
        : current
            ? 'next'
            : 'upcoming';
    return Semantics(
      label: 'Day $day, ${formatNumber(reward)} $coinName, $status',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: current
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: current ? Border.all(color: scheme.primary) : null,
        ),
        // Seven chips share one row: shrink text rather than overflow when
        // the player uses a large font size.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Text('D$day', style: text.labelSmall),
              const SizedBox(height: 2),
              done
                  ? Icon(Icons.check, size: 16, color: scheme.primary)
                  : Text(formatNumber(reward), style: text.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.def, required this.unlocked});

  final AchievementDef def;
  final bool unlocked;

  static const Map<String, IconData> _icons = {
    'first_rig': Icons.power_settings_new,
    'hash_100': Icons.speed,
    'hash_1000': Icons.rocket_launch,
    'coins_10k': Icons.savings,
    'coins_1m': Icons.diamond,
    'streak_7': Icons.local_fire_department,
    'all_rigs': Icons.layers,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '${def.title}, ${unlocked ? 'unlocked' : 'locked'}. '
          '${def.description}',
      excludeSemantics: true,
      // Locked tiles use quieter colours, never transparency, so their text
      // still meets contrast guidelines.
      child: Card(
        key: ValueKey('achievement-${def.id}'),
        margin: EdgeInsets.zero,
        color: unlocked ? scheme.secondaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(unlocked ? _icons[def.id] ?? Icons.star : Icons.lock,
                  color: unlocked ? scheme.primary : scheme.outline),
              const SizedBox(height: 8),
              Text(
                def.title,
                style: text.titleSmall?.copyWith(
                  color: unlocked
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                def.description,
                style: text.bodySmall?.copyWith(
                  color: unlocked
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
