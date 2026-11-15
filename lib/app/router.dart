import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/mine/mine_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shop/shop_screen.dart';
import '../features/stats/stats_screen.dart';
import '../state/providers.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const String welcome = '/welcome';
  static const String mine = '/mine';
  static const String shop = '/shop';
  static const String rewards = '/rewards';
  static const String stats = '/stats';
  static const String settings = '/settings';
}

/// One router per [ProviderScope], so each widget test starts fresh.
///
/// First launch opens the intro (outside the tab shell, so the game doesn't
/// start and "while you were away" waits until the intro is finished).
/// `ref.read`, not `watch`: finishing the intro must not rebuild the router.
final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(onboardingProvider);
  final router = GoRouter(
    initialLocation: onboarded ? Routes.mine : Routes.welcome,
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.mine,
              builder: (context, state) => const MineScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.shop,
              builder: (context, state) => const ShopScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.rewards,
              builder: (context, state) => const RewardsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.stats,
              builder: (context, state) => const StatsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
