import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/cloud/cloud_auth.dart';
import '../../state/cloud/cloud_sync_controller.dart';
import '../../state/cloud/leaderboard_service.dart';
import '../../state/providers.dart';

/// Global top 100 by validated lifetime SimCoin, plus your own rank.
///
/// Opening (or pulling to refresh) first sends your save to the server's
/// validateSync check, which is the only way a score is ever written.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _loading = true;
  String? _error;
  MyStanding? _me;
  String? _myUid;
  List<LeaderboardEntry> _top = const [];

  @override
  void initState() {
    super.initState();
    // After the first frame: loading touches providers (sign-in state),
    // which Riverpod doesn't allow while widgets are still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? error;
    try {
      final cloud = ref.read(cloudSyncProvider.notifier);
      if (ref.read(cloudSyncProvider).phase == CloudPhase.unavailable) {
        throw const CloudException(
            'The leaderboard needs cloud save, which is not available on '
            'this device.');
      }
      await cloud.start();
      final uid = ref.read(cloudSyncProvider).user?.uid;
      if (uid == null) {
        throw const CloudException(
            'Connect to the internet to see the leaderboard.');
      }
      final service = ref.read(leaderboardServiceProvider);
      final me = await service.submit(ref.read(gameControllerProvider));
      final top = await service.top();
      if (!mounted) return;
      setState(() {
        _me = me;
        _myUid = uid;
        _top = top;
      });
    } on CloudException catch (e) {
      error = e.message;
    } on Object catch (e) {
      debugPrint('Leaderboard failed: $e');
      error = 'Could not load the leaderboard. Please try again.';
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _top.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _top.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.leaderboard_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(_error!,
              key: const ValueKey('leaderboard-error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonal(
              key: const ValueKey('leaderboard-retry'),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final me = _me;
    final inTop = _top.any((e) => e.uid == _myUid);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (me != null) _MyCard(standing: me),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 8),
        if (_top.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No scores yet. You could be the first!',
                textAlign: TextAlign.center),
          ),
        for (var i = 0; i < _top.length; i++)
          _Row(
            rank: i + 1,
            name: _top[i].name,
            score: _top[i].score,
            isMe: _top[i].uid == _myUid,
          ),
        if (me != null && !inTop && _top.isNotEmpty) ...[
          const Divider(),
          _Row(rank: me.rank, name: 'You', score: me.score, isMe: true),
        ],
        const SizedBox(height: 16),
        Text(
          'Ranked by lifetime $coinName. Scores are checked on our server, so '
          "changing your phone's clock won't help. Change your name in "
          'Settings. All coins and rankings are virtual.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MyCard extends StatelessWidget {
  const _MyCard({required this.standing});

  final MyStanding standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('my-standing'),
      color: theme.colorScheme.primaryContainer,
      child: MergeSemantics(
        child: ListTile(
          leading: Icon(Icons.emoji_events,
              color: theme.colorScheme.onPrimaryContainer),
          title: Text('Your rank: #${standing.rank}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          subtitle: Text(
            '${formatNumber(standing.score.toDouble())} lifetime $coinName',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.name,
    required this.score,
    required this.isMe,
  });

  final int rank;
  final String name;
  final int score;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: ListTile(
        key: ValueKey('rank-$rank'),
        selected: isMe,
        selectedTileColor: theme.colorScheme.secondaryContainer,
        selectedColor: theme.colorScheme.onSecondaryContainer,
        leading: SizedBox(
          width: 40,
          child: Text('#$rank',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        ),
        title: Text(isMe && name != 'You' ? '$name (you)' : name),
        trailing: Text(formatNumber(score.toDouble()),
            style: theme.textTheme.titleMedium),
      ),
    );
  }
}
