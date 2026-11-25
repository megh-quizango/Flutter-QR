import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Original monoline illustrations for empty, error and permission states.
enum Art { history, noCamera, nothingFound, error, splash }

/// Paths on a 120×120 canvas, drawn in a single stroke weight.
List<Path> _paths(Art art) {
  switch (art) {
    case Art.history:
      return [
        Path()..addRRect(
          RRect.fromLTRBR(22, 18, 86, 102, const Radius.circular(Radii.chip)),
        ),
        Path()
          ..moveTo(36, 40)
          ..lineTo(70, 40)
          ..moveTo(36, 56)
          ..lineTo(62, 56)
          ..moveTo(36, 72)
          ..lineTo(54, 72),
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(84, 82), radius: 18)),
        Path()
          ..moveTo(84, 72)
          ..lineTo(84, 82)
          ..lineTo(91, 87),
      ];
    case Art.noCamera:
      return [
        Path()..addRRect(
          RRect.fromLTRBR(16, 38, 104, 96, const Radius.circular(Radii.chip)),
        ),
        Path()
          ..moveTo(42, 38)
          ..lineTo(48, 26)
          ..lineTo(72, 26)
          ..lineTo(78, 38),
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(60, 66), radius: 16)),
        Path()
          ..moveTo(20, 20)
          ..lineTo(100, 104),
      ];
    case Art.nothingFound:
      return [
        Path()
          ..moveTo(18, 36)
          ..lineTo(18, 20)
          ..lineTo(34, 20)
          ..moveTo(86, 20)
          ..lineTo(102, 20)
          ..lineTo(102, 36)
          ..moveTo(102, 84)
          ..lineTo(102, 100)
          ..lineTo(86, 100)
          ..moveTo(34, 100)
          ..lineTo(18, 100)
          ..lineTo(18, 84),
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(56, 56), radius: 18)),
        Path()
          ..moveTo(69, 69)
          ..lineTo(82, 82),
      ];
    case Art.error:
      return [
        Path()
          ..moveTo(60, 18)
          ..lineTo(104, 96)
          ..lineTo(16, 96)
          ..close(),
        Path()
          ..moveTo(60, 46)
          ..lineTo(60, 70)
          ..moveTo(60, 82)
          ..lineTo(60, 83),
      ];
    case Art.splash:
      return [
        // QR Code corners
        Path()
          ..moveTo(26, 42)
          ..lineTo(26, 26)
          ..lineTo(42, 26)
          ..moveTo(78, 26)
          ..lineTo(94, 26)
          ..lineTo(94, 42)
          ..moveTo(94, 78)
          ..lineTo(94, 94)
          ..lineTo(78, 94)
          ..moveTo(42, 94)
          ..lineTo(26, 94)
          ..lineTo(26, 78),
        // Central scanning laser
        Path()
          ..moveTo(14, 60)
          ..lineTo(106, 60),
        // Little dots in the corners
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(34, 34), radius: 3))
          ..addOval(Rect.fromCircle(center: const Offset(86, 34), radius: 3))
          ..addOval(Rect.fromCircle(center: const Offset(34, 86), radius: 3)),
      ];
  }
}

/// [drawIn]: strokes draw themselves once (M12). [float]: gentle 2 px bob (M13).
/// Both are static under reduced motion; looping stops when the ticker is muted (off-tab, background).
class LineArt extends StatefulWidget {
  const LineArt(
    this.art, {
    super.key,
    this.size = 120,
    this.drawIn = false,
    this.float = false,
    this.color,
  });
  final Art art;
  final double size;
  final bool drawIn, float;
  final Color? color;

  @override
  State<LineArt> createState() => _LineArtState();
}

class _LineArtState extends State<LineArt> with TickerProviderStateMixin {
  late final _draw = AnimationController(
    vsync: this,
    duration: MotionTokens.drawIn,
    value: widget.drawIn ? 0 : 1,
  );
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: MotionTokens.float);
    _draw
        .value; // create both controllers up front so dispose never creates one
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.motion.reduced;
    if (reduced) {
      _draw.value = 1;
      _bob
        ..stop()
        ..value = 0;
    } else {
      if (_draw.value < 1 && !_draw.isAnimating) _draw.forward();
      if (widget.float && !_bob.isAnimating) _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_draw, _bob]),
        builder: (context, _) => Transform.translate(
          offset: Offset(0, -2 * MotionTokens.loopCurve.transform(_bob.value)),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _ArtPainter(
              _paths(widget.art),
              MotionTokens.loopCurve.transform(_draw.value),
              widget.color ?? context.colors.primary,
              context.colors.outlineVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.paths, this.progress, this.ink, this.ground);
  final List<Path> paths;
  final double progress;
  final Color ink, ground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    canvas.drawOval(
      const Rect.fromLTRB(20, 108, 100, 116),
      Paint()..color = ground,
    );
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final total = paths.fold<double>(
      0,
      (a, p) => a + p.computeMetrics().fold(0, (b, m) => b + m.length),
    );
    var budget = total * progress;
    for (final p in paths) {
      for (final PathMetric m in p.computeMetrics()) {
        if (budget <= 0) return;
        canvas.drawPath(m.extractPath(0, math.min(budget, m.length)), stroke);
        budget -= m.length;
      }
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.progress != progress || old.ink != ink || old.ground != ground;
}
