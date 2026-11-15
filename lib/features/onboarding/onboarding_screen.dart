import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../engine/config.dart';
import '../../engine/economy.dart';
import '../../state/providers.dart';
import '../mine/mining_animation.dart';

/// First-launch intro: how the game works, ending on the "this is a game"
/// disclaimer. "Skip" jumps to the disclaimer page rather than past it, so
/// every player sees it before playing (a roadmap guardrail and a store
/// policy safeguard). Also reachable later from Settings → How to play.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  static const int _count = 3;
  static const int _last = _count - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    // Opened from Settings: go back there. First launch: start the game.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.mine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onLast = _page == _last;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: onLast
                    ? const SizedBox(height: 48)
                    : TextButton(
                        key: const ValueKey('onboarding-skip'),
                        onPressed: () => _goTo(_last),
                        child: const Text('Skip'),
                      ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _IntroPage(
                    art: MiningAnimation(hashRate: 25, size: 140),
                    title: 'Build a virtual mining empire',
                    body: 'Buy and upgrade mining rigs in the Shop. They mine '
                        '$coinName for you every second, and bigger rigs '
                        'mine faster.',
                  ),
                  _IntroPage(
                    art: const _ArtIcon(Icons.nightlight_round),
                    title: 'Your rigs never sleep',
                    body: 'Close the game and your rigs keep mining for up to '
                        '${formatDuration(offlineCapSeconds.toDouble())}. '
                        'Come back every day to claim a growing streak '
                        'reward.',
                  ),
                  const _IntroPage(
                    key: ValueKey('onboarding-disclaimer'),
                    art: _ArtIcon(Icons.verified_user_outlined),
                    title: 'Just a game',
                    body: '$appDisclaimer\n\n$coinName has no real-world value '
                        'and cannot be exchanged for money.',
                  ),
                ],
              ),
            ),
            _PageDots(count: _count, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('onboarding-next'),
                  onPressed: onLast ? _finish : () => _goTo(_page + 1),
                  child: Text(onLast ? 'I understand, start mining' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    super.key,
    required this.art,
    required this.title,
    required this.body,
  });

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Centred when it fits; scrolls instead of overflowing at large fonts.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              art,
              const SizedBox(height: 32),
              Text(
                title,
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(body, style: text.bodyLarge, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtIcon extends StatelessWidget {
  const _ArtIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primaryContainer,
        ),
        child: Icon(icon, size: 72, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Page ${current + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
