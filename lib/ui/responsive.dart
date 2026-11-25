import 'package:flutter/material.dart';

/// Material 3 window size classes by width: phones, small tablets and foldables, large screens.
enum WindowSize { compact, medium, expanded }

WindowSize windowSizeFor(double width) => width < 600
    ? WindowSize.compact
    : width < 840
    ? WindowSize.medium
    : WindowSize.expanded;

extension ResponsiveX on BuildContext {
  WindowSize get windowSize => windowSizeFor(MediaQuery.sizeOf(this).width);
}

/// Content widths: reading columns stay comfortable however wide the window gets.
abstract final class ContentWidth {
  static const form = 640.0; // result, sheets, privacy
  static const list = 760.0; // history, settings
  static const wide =
      1080.0; // home, create, created (two columns when expanded)
}

/// How far content capped at [max] sits in from each edge, so app bar titles can line up with it.
double sideInset(BuildContext context, double max) =>
    ((MediaQuery.sizeOf(context).width - max) / 2).clamp(0, double.infinity);

/// Centres [child] and caps its width. The background stays full-bleed around it.
class MaxWidth extends StatelessWidget {
  const MaxWidth(this.max, {required this.child, super.key});
  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max),
      child: child,
    ),
  );
}
