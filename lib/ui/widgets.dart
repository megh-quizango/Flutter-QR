import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'line_art.dart';
import 'app_icons.dart';

IconData typeIcon(ContentType t) => switch (t) {
  ContentType.url => AppIcon.link,
  ContentType.text => AppIcon.text,
  ContentType.wifi => AppIcon.wifi,
  ContentType.contact => AppIcon.user,
  ContentType.email => AppIcon.mail,
  ContentType.phone => AppIcon.phone,
  ContentType.sms => AppIcon.message,
  ContentType.geo => AppIcon.pin,
  ContentType.event => AppIcon.calendar,
  ContentType.product => AppIcon.bag,
};

String typeLabel(ContentType t) => switch (t) {
  ContentType.url => 'Website',
  ContentType.text => 'Text',
  ContentType.wifi => 'Wi-Fi',
  ContentType.contact => 'Contact',
  ContentType.email => 'Email',
  ContentType.phone => 'Phone',
  ContentType.sms => 'SMS',
  ContentType.geo => 'Location',
  ContentType.event => 'Event',
  ContentType.product => 'Product',
};

/// One readable line about a record ("WPA · Café Guest", the link host, the number…), not the raw payload.
String recordSummary(ScanRecord r) {
  final d = r.parsed;
  String s(String k) => (d[k] as String?)?.trim() ?? '';
  String first(String k) =>
      ((d[k] as List?)?.cast<String>() ?? const []).firstOrNull ?? '';
  final line = switch (r.type) {
    ContentType.url => s('url').replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
    ContentType.wifi =>
      s('security') == 'nopass' ? 'Open network' : '${s('security')} network',
    ContentType.contact => [
      first('phones'),
      first('emails'),
      s('org'),
    ].firstWhere((x) => x.isNotEmpty, orElse: () => 'Contact card'),
    ContentType.email => s('subject').isEmpty ? s('to') : s('subject'),
    ContentType.phone => s('number'),
    ContentType.sms => s('body').isEmpty ? s('number') : s('body'),
    ContentType.geo =>
      s('query').isEmpty ? '${d['lat']}, ${d['lng']}' : s('query'),
    ContentType.event =>
      s('location').isEmpty ? 'Calendar event' : s('location'),
    ContentType.product => s('code'),
    ContentType.text => r.rawValue,
  };
  final clean = line.replaceAll('\n', ' ').trim();
  final source = r.source == ScanSource.created ? 'Created' : typeLabel(r.type);
  return clean.isEmpty || clean == r.title ? source : '$source · $clean';
}

/// Content-type icon in a circle. Neutral by default (lists stay quiet); [solid] fills it with
/// the type's colour for the few places that colour carries meaning.
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key, this.size = 48, this.solid = false});
  final ContentType type;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final h = context.hue(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? h.strong : context.colors.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(
        typeIcon(type),
        size: size * 0.46,
        color: solid ? h.onStrong : context.colors.onSurface,
        semanticLabel: typeLabel(type),
      ),
    );
  }
}

/// The signature detail: viewfinder corner brackets, as on the scanner, framing [child].
class Brackets extends StatelessWidget {
  const Brackets({
    required this.child,
    required this.color,
    super.key,
    this.arm = Space.x4,
    this.stroke = 2,
  });
  final Widget child;
  final Color color;
  final double arm, stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _BracketPainter(color, arm, stroke),
    child: child,
  );
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color, this.arm, this.stroke);
  final Color color;
  final double arm, stroke;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final h = stroke / 2;
    for (final (x, y, dx, dy) in [
      (h, h, 1.0, 1.0),
      (s.width - h, h, -1.0, 1.0),
      (h, s.height - h, 1.0, -1.0),
      (s.width - h, s.height - h, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * arm)
          ..lineTo(x, y)
          ..lineTo(x + dx * arm, y),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_BracketPainter o) =>
      o.color != color || o.arm != arm || o.stroke != stroke;
}

/// Press feedback: scales to 0.97 while held (M4, `instant`).
class PressScale extends StatefulWidget {
  const PressScale({required this.child, super.key});
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: context.motion.instant,
      curve: context.motion.instantCurve,
      child: widget.child,
    ),
  );
}

/// Fade + 8 px slide up after `index × step`. Renders the end state at once under reduced motion,
/// and [skip] jumps straight to the end (interruptible).
class Reveal extends StatefulWidget {
  const Reveal({
    required this.child,
    required this.index,
    required this.step,
    super.key,
    this.skip = false,
  });
  final Widget child;
  final int index;
  final Duration step;
  final bool skip;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: MotionTokens.quick,
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced || widget.skip) {
      _c.value = 1;
    } else if (_c.value == 0 && _timer == null) {
      _timer = Timer(widget.step * widget.index, () => _c.forward());
    }
  }

  @override
  void didUpdateWidget(Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.skip) {
      _timer?.cancel();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: MotionTokens.quickCurve);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - a.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Designed empty / error / permission state.
class StatusView extends StatelessWidget {
  const StatusView({
    required this.art,
    required this.title,
    super.key,
    this.body,
    this.action,
    this.drawIn = false,
    this.float = false,
    this.onDark = false,
  });
  final Art art;
  final String title;
  final String? body;
  final Widget? action;
  final bool drawIn, float, onDark;

  @override
  Widget build(BuildContext context) {
    final ink = onDark ? context.tokens.onCamera : context.colors.onSurface;
    final muted = onDark
        ? context.tokens.onCameraMuted
        : context.colors.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x8,
          vertical: Space.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LineArt(
              art,
              drawIn: drawIn,
              float: float,
              color: onDark ? context.tokens.signal : null,
            ),
            const SizedBox(height: Space.x6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(color: ink),
            ),
            if (body != null) ...[
              const SizedBox(height: Space.x2),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Space.x6),
              // CTA fades in last after a draw-in (M12).
              drawIn
                  ? Reveal(index: 1, step: MotionTokens.drawIn, child: action!)
                  : action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton, shown only if loading lasts longer than 300 ms.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.rows = 6});
  final int rows;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Timer _show;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: MotionTokens.shimmer);
    _show = Timer(MotionTokens.skeletonDelay, () {
      if (!mounted) return;
      setState(() => _visible = true);
      if (!context.motion.reduced) _c.repeat();
    });
  }

  @override
  void dispose() {
    _show.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final base = context.colors.surfaceContainerHigh;
    final hi = context.colors.surfaceContainerLowest;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            colors: [base, hi, base],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment(-1 + 3 * _c.value - 1, 0),
            end: Alignment(1 + 3 * _c.value - 1, 0),
          ).createShader(r),
          child: child,
        ),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.rows,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
              vertical: Space.x3,
            ),
            child: Row(
              children: [
                Container(
                  width: Space.tap,
                  height: Space.tap,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Space.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(180, 14),
                      const SizedBox(height: Space.x2),
                      bar(110, 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header used in settings and history: quiet secondary text, closer to its group.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter + Space.x1,
      Space.x6,
      Space.gutter,
      Space.x2,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: context.text.titleSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ),
  );
}
