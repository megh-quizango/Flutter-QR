import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../features/home/home_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/create/create_screen.dart';
import '../features/create/created_screen.dart';
import '../features/history/history_screen.dart';
import '../features/scan/scanner_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/settings_screen.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'providers.dart';
import '../theme/app_theme.dart';
import '../ui/app_icons.dart';
import '../ui/responsive.dart';

/// Platform page transition (predictive back on Android, swipe-back on iOS); none under reduced motion.
Page<void> _page(BuildContext context, GoRouterState state, Widget child) =>
    context.motion.reduced
    ? NoTransitionPage(key: state.pageKey, child: child)
    : MaterialPage(key: state.pageKey, child: child);

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    StatefulShellRoute(
      builder: (context, state, shell) => HomeShell(shell: shell),
      navigatorContainerBuilder: (context, shell, children) =>
          _FadeThroughBranches(index: shell.currentIndex, children: children),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/scan', builder: (_, _) => const ScannerScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/created',
      pageBuilder: (c, s) =>
          _page(c, s, CreatedScreen(record: s.extra! as ScanRecord)),
    ),
    GoRoute(
      path: '/privacy',
      pageBuilder: (c, s) => _page(c, s, const PrivacyScreen()),
    ),
  ],
);

/// Switches bottom tab and tells the scanner whether it is visible.
void goTab(BuildContext context, WidgetRef ref, int index) {
  final shell = StatefulNavigationShell.of(context);
  ref.read(currentTabProvider.notifier).state = index;
  shell.goBranch(index, initialLocation: index == shell.currentIndex);
}

/// Bottom navigation bar on phones; a navigation rail beside the content from 600 dp up,
/// where a bottom bar would stretch across a tablet.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (AppIcon.home, 'Home'),
    (AppIcon.scan, 'Scan'),
    (AppIcon.create, 'Create'),
    (AppIcon.history, 'History'),
    (AppIcon.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(int i) {
      if (i != shell.currentIndex) Haptics.select();
      ref.read(currentTabProvider.notifier).state = i;
      shell.goBranch(i, initialLocation: i == shell.currentIndex);
    }

    if (context.windowSize == WindowSize.compact) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          animationDuration: context.motion.standard, // indicator slide (M5)
          onDestinationSelected: select,
          destinations: [
            for (final (icon, label) in _tabs)
              NavigationDestination(icon: Icon(icon), label: label),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.2,
              destinations: [
                for (final (icon, label) in _tabs)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    label: Text(label),
                  ),
              ],
            ),
          ),
          VerticalDivider(
            width: 1,
            color: context.colors.onSurface.withValues(
              alpha: Opacities.hairline,
            ),
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

/// Keeps every branch alive (scroll state survives) and fades through on switch (M5).
/// Hidden branches are offstage with tickers muted, so their loops stop.
class _FadeThroughBranches extends StatefulWidget {
  const _FadeThroughBranches({required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<_FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<_FadeThroughBranches>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: MotionTokens.standard,
    value: 1,
  );
  late int _previous = widget.index;

  @override
  void didUpdateWidget(_FadeThroughBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previous = oldWidget.index;
      _c.duration = context.motion.standard;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final animating = _c.isAnimating;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _branch(
              i,
              current: i == widget.index,
              leaving: animating && i == _previous,
            ),
        ],
      );
    },
  );

  // Same widget shape for every branch in every frame, so Navigator state is never rebuilt.
  Widget _branch(int i, {required bool current, required bool leaving}) =>
      Offstage(
        offstage: !(current || leaving),
        child: TickerMode(
          enabled: current,
          child: IgnorePointer(
            ignoring: !current,
            child: FadeThroughTransition(
              animation: current ? _c : kAlwaysCompleteAnimation,
              secondaryAnimation: leaving ? _c : kAlwaysDismissedAnimation,
              child: widget.children[i],
            ),
          ),
        ),
      );
}
