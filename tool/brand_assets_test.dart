/// Generates the app icon, splash and notification artwork from the same
/// fan + SimCoin drawing the app uses (lib/app/brand_widgets.dart), so they
/// always match the in-game look. Run after changing the artwork:
///
///   flutter test tool/brand_assets_test.dart
///   dart run flutter_launcher_icons
///   dart run flutter_native_splash:create
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/app/brand_widgets.dart';
import 'package:idle_miner_sim/app/theme.dart';

const _navy = Color(0xFF0E1726);
const _navyGlow = Color(0xFF1C2D4B);
const _gold = Color(0xFFF2B544);
const _white = Color(0xFFFFFFFF);

enum _Style {
  /// Full-bleed icon: navy background, gold fan, coin hub (iOS, legacy).
  full,

  /// Transparent, gold fan + coin: adaptive foreground and splash images.
  art,

  /// One colour on transparent: Android 13 themed icon, notification icon.
  silhouette,
}

class _BrandArt extends CustomPainter {
  _BrandArt(this.style, {required this.fanScale});

  final _Style style;

  /// Fan radius as a share of half the canvas.
  final double fanScale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2;
    final r = half * fanScale;

    if (style == _Style.full) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
              c, half * 1.1, const [_navyGlow, _navy], const [0, 1]),
      );
    }

    final colour = style == _Style.silhouette ? _white : _gold;
    paintFan(canvas, c, r, blade: colour, ring: colour);

    final hubR = r * fanHubRatio * 1.25; // the coin sits slightly proud
    if (style == _Style.silhouette) {
      // Solid hub with the "S" knocked out, so it still reads as a coin.
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawCircle(c, hubR, Paint()..color = _white);
      _drawS(canvas, c, hubR, Paint()..blendMode = BlendMode.clear);
      canvas.restore();
    } else {
      // Navy gap so the coin separates from the blades, then the coin.
      canvas.drawCircle(c, hubR * 1.12, Paint()..color = _navy);
      const coin = AppColors.dark;
      canvas
        ..drawCircle(
          c,
          hubR,
          Paint()
            ..shader = ui.Gradient.radial(
              c + Offset(-hubR * 0.3, -hubR * 0.4),
              hubR * 1.4,
              [Color.lerp(coin.coinFace, _white, 0.35)!, coin.coinFace],
            ),
        )
        ..drawCircle(
          c,
          hubR * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hubR * 0.14
            ..color = coin.coinRim,
        );
      _drawS(canvas, c, hubR, Paint()..color = coin.coinMark);
    }
  }

  void _drawS(Canvas canvas, Offset c, double hubR, Paint paint) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: hubR * 1.25,
          fontWeight: FontWeight.w900,
          height: 1,
          foreground: paint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BrandArt old) => false;
}

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final file =
      File('$root/bin/cache/artifacts/material_fonts/roboto-black.ttf');
  await (FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
      .load();
}

Future<void> _render(
  WidgetTester tester,
  String path,
  int size,
  _Style style, {
  required double fanScale,
}) async {
  tester.view.physicalSize = Size(size.toDouble(), size.toDouble());
  tester.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await tester.pumpWidget(Center(
    child: RepaintBoundary(
      key: key,
      child: CustomPaint(
        size: Size.square(size.toDouble()),
        painter: _BrandArt(style, fanScale: fanScale),
      ),
    ),
  ));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadRoboto);
  tearDown(() => TestWidgetsFlutterBinding
      .instance.platformDispatcher.views.first
      .reset());

  const out = 'assets/branding';

  testWidgets('app icon (full bleed, iOS + legacy Android)', (t) async {
    await _render(t, '$out/app_icon.png', 1024, _Style.full, fanScale: 0.78);
  });

  testWidgets('adaptive icon foreground (inside the 66% safe zone)', (t) async {
    await _render(t, '$out/app_icon_foreground.png', 1024, _Style.art,
        fanScale: 0.56);
  });

  testWidgets('themed icon (Android 13+ monochrome)', (t) async {
    await _render(t, '$out/app_icon_monochrome.png', 1024, _Style.silhouette,
        fanScale: 0.56);
  });

  testWidgets('splash image (Android 12+, shown inside a circle)', (t) async {
    await _render(t, '$out/splash_android12.png', 1152, _Style.art,
        fanScale: 0.58);
  });

  testWidgets('splash image (older Android + iOS)', (t) async {
    await _render(t, '$out/splash.png', 600, _Style.art, fanScale: 0.9);
  });

  // Android status-bar icon: white on transparent, one file per density.
  const densities = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96,
  };
  for (final e in densities.entries) {
    testWidgets('notification icon ${e.key}', (t) async {
      await _render(
        t,
        'android/app/src/main/res/drawable-${e.key}/ic_notification.png',
        e.value,
        _Style.silhouette,
        fanScale: 0.92,
      );
    });
  }
}
