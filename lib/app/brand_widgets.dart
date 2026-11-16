import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/config.dart';
import '../engine/economy.dart';
import 'theme.dart';

/// The SimCoin: a gold coin with a rim and an "S". Drawn in code, so it is
/// crisp at any size and needs no image assets.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(c.coinFace, Colors.white, 0.35)!, c.coinFace],
          ),
          border: Border.all(color: c.coinRim, width: math.max(1, size / 12)),
        ),
        alignment: Alignment.center,
        child: Text(
          'S',
          style: TextStyle(
            color: c.coinMark,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// A coin amount: coin icon + compact number. Screen readers hear
/// "1.2K SimCoin".
class CoinAmount extends StatelessWidget {
  const CoinAmount(
    this.amount, {
    super.key,
    this.style,
    this.iconSize,
    this.prefix = '',
    this.suffix = '',
  });

  final double amount;
  final TextStyle? style;
  final double? iconSize;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final effective = style ?? DefaultTextStyle.of(context).style;
    final size = iconSize ?? (effective.fontSize ?? 14) * 1.05;
    final text = '$prefix${formatNumber(amount)}$suffix';
    return Semantics(
      label: '$text $coinName',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: size),
          SizedBox(width: size * 0.3),
          Flexible(child: Text(text, style: effective)),
        ],
      ),
    );
  }
}

/// One recognisable icon per rig type, on a soft gold tile.
class RigIcon extends StatelessWidget {
  const RigIcon(this.rigId, {super.key, this.size = 44});

  final String rigId;
  final double size;

  static IconData iconFor(String rigId) => switch (rigId) {
        'cpu' => Icons.memory,
        'gpu' => Icons.developer_board,
        'asic_mini' => Icons.dns_outlined,
        'asic_pro' => Icons.storage,
        'farm' => Icons.factory_outlined,
        _ => Icons.memory,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.accentTint,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        alignment: Alignment.center,
        child: Icon(iconFor(rigId), color: c.accent, size: size * 0.55),
      ),
    );
  }
}

/// A cooling fan: curved blades inside a ring. Rotated by MiningAnimation.
class MiningFan extends StatelessWidget {
  const MiningFan({super.key, required this.active, this.size = 96});

  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _FanPainter(
        // Real gold blades in both modes; the ring uses the readable accent.
        blade: active ? c.coinFace : scheme.outline,
        ring: active ? c.accent : scheme.outline,
        hub: scheme.surfaceContainerHigh,
      ),
    );
  }
}

/// A PC-style cooling fan: swept blades between a hub and an outer ring.
class _FanPainter extends CustomPainter {
  _FanPainter({required this.blade, required this.hub, required this.ring});

  final Color blade;
  final Color hub;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    Offset polar(double radius, double angle) =>
        c + Offset(math.cos(angle), math.sin(angle)) * radius;

    canvas.drawCircle(
      c,
      r * 0.93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = ring,
    );

    final bladePaint = Paint()..color = blade;
    final hubR = r * 0.24;
    final tipR = r * 0.82;
    const blades = 7;
    for (var i = 0; i < blades; i++) {
      final a = i * 2 * math.pi / blades;
      // Root on the hub, sweeping out to a wide tip: reads as a fan blade.
      final path = Path()
        ..moveTo(polar(hubR, a - 0.22).dx, polar(hubR, a - 0.22).dy)
        ..quadraticBezierTo(
          polar(r * 0.62, a - 0.05).dx,
          polar(r * 0.62, a - 0.05).dy,
          polar(tipR, a + 0.18).dx,
          polar(tipR, a + 0.18).dy,
        )
        ..arcToPoint(
          polar(tipR, a + 0.62),
          radius: Radius.circular(tipR),
        )
        ..quadraticBezierTo(
          polar(r * 0.55, a + 0.42).dx,
          polar(r * 0.55, a + 0.42).dy,
          polar(hubR, a + 0.24).dx,
          polar(hubR, a + 0.24).dy,
        )
        ..close();
      canvas.drawPath(path, bladePaint);
    }
    canvas
      ..drawCircle(c, hubR, Paint()..color = hub)
      ..drawCircle(
          c,
          hubR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = ring)
      ..drawCircle(c, r * 0.08, Paint()..color = ring);
  }

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.blade != blade || old.hub != hub || old.ring != ring;
}
