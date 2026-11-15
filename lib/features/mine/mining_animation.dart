import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/economy.dart';

/// A rig "fan" that spins faster as hash rate grows and stops when idle.
///
/// Respects the OS "remove animations" setting, sits in its own
/// [RepaintBoundary] so spinning never repaints the rest of the screen, and
/// stops ticking automatically when its tab is hidden (TickerMode).
class MiningAnimation extends StatefulWidget {
  const MiningAnimation({super.key, required this.hashRate, this.size = 120});

  final double hashRate;
  final double size;

  /// Seconds per full turn: ~4 s at 1 TH/s down to 0.5 s for huge farms.
  static Duration periodFor(double hashRate) {
    if (hashRate <= 0) return const Duration(seconds: 4);
    final seconds =
        (4 / (1 + math.log(1 + hashRate) / math.ln10)).clamp(0.5, 4.0);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  State<MiningAnimation> createState() => _MiningAnimationState();
}

class _MiningAnimationState extends State<MiningAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: MiningAnimation.periodFor(widget.hashRate),
  );

  bool get _shouldSpin =>
      widget.hashRate > 0 && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MiningAnimation old) {
    super.didUpdateWidget(old);
    final period = MiningAnimation.periodFor(widget.hashRate);
    if (period != _spin.duration) {
      _spin.duration = period;
      if (_spin.isAnimating) _spin.repeat(); // pick up the new speed
    }
    _sync();
  }

  void _sync() {
    if (_shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!_shouldSpin && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.hashRate > 0;
    return Semantics(
      label: active
          ? 'Rigs mining at ${formatNumber(widget.hashRate)} TH/s'
          : 'Rigs idle',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                (active ? scheme.primary : scheme.outline)
                    .withValues(alpha: 0.25),
                Colors.transparent,
              ]),
            ),
            child: RotationTransition(
              key: const ValueKey('mining-spinner'),
              turns: _spin,
              child: Icon(
                Icons.settings,
                size: widget.size * 0.7,
                color: active ? scheme.primary : scheme.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A number that rolls up smoothly to each new value (e.g. once-a-second
/// earnings) but snaps instantly when it goes down (spending), so a purchase
/// never looks like the balance is slowly draining.
class RollingNumber extends StatefulWidget {
  const RollingNumber({
    super.key,
    required this.value,
    this.style,
    this.textAlign,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll =
      AnimationController(vsync: this, duration: widget.duration, value: 1);
  late double _from = widget.value;
  late double _to = widget.value;

  double get _shown => _from + (_to - _from) * _roll.value;

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (widget.value == _to) return;
    final current = _shown;
    if (widget.value < current || MediaQuery.disableAnimationsOf(context)) {
      _from = _to = widget.value;
      _roll.value = 1;
    } else {
      _from = current;
      _to = widget.value;
      _roll.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _roll,
        builder: (context, _) => Text(
          formatNumber(_shown),
          style: widget.style,
          textAlign: widget.textAlign,
        ),
      ),
    );
  }
}
