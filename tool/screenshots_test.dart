/// Design review screenshots (not part of the test suite).
///
/// Renders the main screens with real Roboto + Material Icons fonts on a
/// 360 x 780 dp phone, in dark and light, and writes PNGs to
/// build/screenshots/. Run:
///
///   flutter test tool/screenshots_test.dart --update-goldens
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_miner_sim/app/app.dart';
import 'package:idle_miner_sim/engine/economy.dart';
import 'package:idle_miner_sim/state/theme_mode_controller.dart';

import '../test/support/app_harness.dart';
import '../test/support/fixtures.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  ByteData read(String f) =>
      ByteData.sublistView(File('$dir/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(Future.value(read(f)));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(read('materialicons-regular.otf'))))
      .load();
}

void main() {
  setUpAll(_loadFonts);

  final played = tick(
    stateWith(rigLevels: {'cpu': 5, 'gpu': 2, 'asic_mini': 1}, coins: 12480)
        .copyWith(
      lifetimeCoins: 18000,
      lastClaimDay: dayKey(t0 - dayMs),
      streak: 3,
      achievements: ['first_rig', 'coins_10k'],
      playerName: 'Rig Runner',
    ),
    t0 + 5 * hourMs,
  );

  for (final mode in ['dark', 'light']) {
    for (final tab in ['Mine', 'Shop', 'Rewards', 'Stats', 'Settings']) {
      testWidgets('$mode $tab', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final clock = FakeClock(played.lastTick);
        await pumpApp(tester, clock, saved: {
          ...savedGame(played),
          ThemeModeController.key: mode,
        });
        if (tab != 'Mine') await openTab(tester, tab);
        await expectLater(
          find.byType(IdleMinerApp),
          matchesGoldenFile('../build/screenshots/$mode-$tab.png'),
        );
      });
    }

    testWidgets('$mode intro', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpApp(tester, FakeClock(t0),
          onboarded: false, saved: {ThemeModeController.key: mode});
      await expectLater(
        find.byType(IdleMinerApp),
        matchesGoldenFile('../build/screenshots/$mode-intro.png'),
      );
    });
  }
}
