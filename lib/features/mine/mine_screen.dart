import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/config.dart';
import '../../engine/economy.dart';

/// M0 placeholder home screen: a live earnings counter driven by the engine,
/// one starter rig to buy, and the required "this is a game" disclaimer.
/// Proper state management (Riverpod) and the full screen set arrive in M2.
class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  late GameState _state;
  Timer? _timer;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _state = GameState.newGame(_now);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _state = tick(_state, _now));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _buyFirstRig() {
    final next = buyRig(_state, 'cpu', _now);
    if (next != null) {
      setState(() => _state = next);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough SimCoin yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = _state.rigs['cpu'] ?? 0;
    final cost = rigCost('cpu', level);
    return Scaffold(
      appBar: AppBar(title: const Text('Idle Miner Sim')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text('$coinName balance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              formatNumber(_state.coins),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatNumber(totalHash(_state))} TH/s  ·  '
              '${formatNumber(baseCoinsPerSecond(_state))} $coinName/s',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _buyFirstRig,
              child: Text(
                  'Buy CPU Rack (Lv $level)  —  ${formatNumber(cost)} $coinName'),
            ),
            const SizedBox(height: 24),
            Text(
              appDisclaimer,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
