import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/config.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../state/reminders_controller.dart';
import 'away_dialog.dart';
import 'reminder_prompt.dart';

/// Bottom-navigation frame around the tabs. It also:
/// - forwards app lifecycle events to the [GameController] (settle + save)
///   and the [RemindersController] (schedule on pause, cancel on resume);
/// - shows the "while you were away" dialog on launch and on resume;
/// - announces newly unlocked achievements.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  GameController get _game => ref.read(gameControllerProvider.notifier);
  RemindersController get _reminders => ref.read(remindersProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: _onPause,
      onResume: _onResume,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reminders.onAppResumed()); // the player is here now
      unawaited(_showAway(_game.takeAwayReport()));
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onPause() {
    _game.onPaused();
    unawaited(_reminders.onAppPaused(
      ref.read(gameControllerProvider),
      ref.read(clockProvider)(),
    ));
  }

  void _onResume() {
    unawaited(_reminders.onAppResumed());
    unawaited(_showAway(_game.onResumed()));
  }

  Future<void> _showAway(AwayReport? report) async {
    if (report == null || !mounted) return;
    await showAwayDialog(context, report);
    if (mounted) {
      await maybeOfferReminders(context, ref, ReminderReason.storage);
    }
  }

  void _announceAchievements(List<String>? before, List<String> after) {
    // Null on first build; shorter after a reset. Only celebrate additions.
    if (before == null || after.length <= before.length) return;
    final titles = [
      for (final a in achievements)
        if (after.contains(a.id) && !before.contains(a.id)) a.title,
    ];
    if (titles.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Achievement unlocked: ${titles.join(', ')}'),
      action: SnackBarAction(
        label: 'View',
        onPressed: () => widget.shell.goBranch(_rewardsTab),
      ),
    ));
  }

  static const int _rewardsTab = 2;

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(
      gameControllerProvider.select((s) => s.achievements),
      _announceAchievements,
    );
    final shell = widget.shell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again returns it to its first page.
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Mine',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
