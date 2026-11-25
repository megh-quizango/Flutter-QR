import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';

/// Maps barcode corner points (image pixels) onto the preview, which is drawn with BoxFit.cover.
/// Returns null when the mapping is unusable, so the caller falls back to the frame.
Rect? mapBarcodeBox(List<Offset> corners, Size image, Size view) {
  if (corners.length < 2 || image.isEmpty || view.isEmpty) return null;
  final scale = math.max(view.width / image.width, view.height / image.height);
  final dx = (view.width - image.width * scale) / 2;
  final dy = (view.height - image.height * scale) / 2;
  final pts = corners.map((c) => Offset(c.dx * scale + dx, c.dy * scale + dy));
  final rect = Rect.fromLTRB(
    pts.map((p) => p.dx).reduce(math.min),
    pts.map((p) => p.dy).reduce(math.min),
    pts.map((p) => p.dx).reduce(math.max),
    pts.map((p) => p.dy).reduce(math.max),
  );
  final onScreen = (Offset.zero & view).intersect(rect);
  if (onScreen.width < Space.x6 || onScreen.height < Space.x6) return null;
  return rect.inflate(Space.x2);
}

/// Scan frame with corner brackets.
/// M1: brackets breathe and a scan line sweeps while [active]; both stop otherwise or under reduced motion.
/// M2: [ScanOverlayState.detect] snaps the brackets to the code, tints them and flashes once.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({required this.active, super.key});
  final bool active;

  @override
  State<ScanOverlay> createState() => ScanOverlayState();
}

class ScanOverlayState extends State<ScanOverlay>
    with TickerProviderStateMixin {
  late final _breathe = AnimationController(
    vsync: this,
    duration: MotionTokens.breathe,
  );
  late final _sweep = AnimationController(
    vsync: this,
    duration: MotionTokens.sweep,
  );
  late final _detect = AnimationController(
    vsync: this,
    duration: MotionTokens.slow,
  );
  Rect? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoops();
  }

  @override
  void didUpdateWidget(ScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoops();
  }

  void _syncLoops() {
    final run = widget.active && !context.motion.reduced && _detect.value == 0;
    if (run) {
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
      if (!_sweep.isAnimating) _sweep.repeat(reverse: true);
    } else {
      _breathe.stop();
      _sweep.stop();
    }
  }

  /// Plays M2 and completes when the brackets have landed. [box] null = stay on the frame.
  Future<void> detect(Rect? box) async {
    _target = box;
    _breathe.stop();
    _sweep.stop();
    _detect.duration = context.motion.slow;
    await _detect.forward(from: 0).orCancel.catchError((_) {});
  }

  void reset() {
    _detect.value = 0;
    _target = null;
    _syncLoops();
  }

  @override
  void dispose() {
    _breathe.dispose();
    _sweep.dispose();
    _detect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = context.motion.reduced;
    final tokens = context.tokens;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathe, _sweep, _detect]),
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _OverlayPainter(
              breathe: MotionTokens.loopCurve.transform(_breathe.value),
              sweep: reduced
                  ? 0.5
                  : MotionTokens.loopCurve.transform(_sweep.value),
              detect: _detect.value,
              target: _target,
              flash: !reduced,
              idle: tokens.onCamera,
              signal: tokens.signal,
              scrim: tokens.cameraScrim,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.breathe,
    required this.sweep,
    required this.detect,
    required this.target,
    required this.flash,
    required this.idle,
    required this.signal,
    required this.scrim,
  });

  final double breathe, sweep, detect;
  final Rect? target;
  final bool flash;
  final Color idle, signal, scrim;

  static Rect frameFor(Size size) {
    final side = math.min(size.shortestSide * 0.68, 360.0); // capped on tablets
    return Rect.fromCenter(
      center: size.center(Offset.zero) - const Offset(0, Space.x12),
      width: side,
      height: side,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frameFor(size);
    final scale = 1 + 0.03 * breathe;
    final idleRect = Rect.fromCenter(
      center: frame.center,
      width: frame.width * scale,
      height: frame.height * scale,
    );
    final t = MotionTokens.springCurve.transform(detect);
    final rect = Rect.lerp(idleRect, target ?? idleRect, t)!;
    final radius = Radius.circular(Radii.card * (1 - 0.5 * t));
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Scrim around the frame; dims further on detection.
    final scrimAlpha =
        Opacities.scrimIdle +
        (Opacities.scrimDetected - Opacities.scrimIdle) * detect;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rrect),
      ),
      Paint()..color = scrim.withValues(alpha: scrimAlpha),
    );

    // Scan line fades out as detection starts.
    if (detect < 1) {
      final y = rect.top + Space.x3 + (rect.height - Space.x6) * sweep;
      canvas.drawLine(
        Offset(rect.left + Space.x4, y),
        Offset(rect.right - Space.x4, y),
        Paint()
          ..color = signal.withValues(alpha: 1 - detect)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // One flash inside the box at the start of M2.
    if (flash && detect > 0 && detect < 0.5) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = signal.withValues(
            alpha: Opacities.flash * math.sin(detect * 2 * math.pi),
          ),
      );
    }

    // Corner brackets.
    final color = Color.lerp(idle, signal, detect.clamp(0, 1))!;
    final arm = math.min(Space.x8, rect.shortestSide / 3);
    final r = radius.x;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (corner, sx, sy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomRight, -1.0, -1.0),
      (rect.bottomLeft, 1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(corner.dx, corner.dy + sy * arm)
        ..lineTo(corner.dx, corner.dy + sy * r)
        ..arcToPoint(
          Offset(corner.dx + sx * r, corner.dy),
          radius: radius,
          clockwise: sx * sy > 0,
        )
        ..lineTo(corner.dx + sx * arm, corner.dy);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter o) =>
      o.breathe != breathe ||
      o.sweep != sweep ||
      o.detect != detect ||
      o.target != target ||
      o.idle != idle;
}
