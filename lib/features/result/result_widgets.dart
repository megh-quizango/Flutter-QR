import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../../ui/app_icons.dart';

/// Tonal icon-and-label button with press scale. [primary] gives the full-width 56 px filled style.
class ActionButton extends StatelessWidget {
  const ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.primary = false,
  });
  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => PressScale(
    child: primary
        ? FilledButton.icon(onPressed: onPressed, icon: icon, label: label)
        : FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: icon,
            label: label,
            // secondary actions size to content, unlike the full-width primary
            style: FilledButton.styleFrom(
              minimumSize: const Size(Space.tap, Space.tap),
            ),
          ),
  );
}

/// Copy: label swaps to "Copied ✓" for 1.2 s (M4). No snackbar.
class CopyButton extends StatefulWidget {
  const CopyButton({
    required this.text,
    super.key,
    this.label = 'Copy',
    this.primary = false,
    this.icon = AppIcon.copy,
  });
  final String text, label;
  final bool primary;
  final IconData icon;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _t;

  Future<void> _copy() async {
    Haptics.select();
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Copied',
      Directionality.of(context),
    );
    _t?.cancel();
    _t = Timer(
      MotionTokens.copiedHold,
      () => mounted ? setState(() => _copied = false) : null,
    );
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = context.motion.quick;
    return ActionButton(
      primary: widget.primary,
      onPressed: _copy,
      icon: AnimatedSwitcher(
        duration: d,
        child: Icon(
          _copied ? AppIcon.check : widget.icon,
          key: ValueKey(_copied),
        ),
      ),
      label: AnimatedSwitcher(
        duration: d,
        child: Text(_copied ? 'Copied' : widget.label, key: ValueKey(_copied)),
      ),
    );
  }
}

enum _ConnectState { idle, working, ok, failed }

/// Wi-Fi Connect: progress ring, then an animated tick or a shake (M4).
class ConnectButton extends StatefulWidget {
  const ConnectButton({
    required this.connect,
    required this.onResult,
    super.key,
  });
  final Future<bool> Function() connect;
  final ValueChanged<bool> onResult;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: MotionTokens.slow,
  );
  _ConnectState _s = _ConnectState.idle;

  Future<void> _go() async {
    if (_s == _ConnectState.working) return;
    Haptics.select();
    setState(() => _s = _ConnectState.working);
    final ok = await widget.connect();
    if (!mounted) return;
    setState(() => _s = ok ? _ConnectState.ok : _ConnectState.failed);
    if (ok) {
      Haptics.success();
    } else {
      Haptics.failure();
      if (!context.motion.reduced) _shake.forward(from: 0);
    }
    widget.onResult(ok);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, label) = switch (_s) {
      _ConnectState.idle => (
        const Icon(AppIcon.wifi, key: ValueKey(0)),
        'Connect',
      ),
      _ConnectState.working => (
        SizedBox.square(
          key: const ValueKey(1),
          dimension: Space.x4 + Space.x1,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.onPrimary,
          ),
        ),
        'Connecting…',
      ),
      _ConnectState.ok => (const _Tick(key: ValueKey(2)), 'Connected'),
      _ConnectState.failed => (
        const Icon(AppIcon.wifiOff, key: ValueKey(3)),
        'Try again',
      ),
    };
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          Space.x2 * math.sin(_shake.value * 6 * math.pi) * (1 - _shake.value),
          0,
        ),
        child: child,
      ),
      child: ActionButton(
        primary: true,
        onPressed: _go,
        icon: AnimatedSwitcher(duration: context.motion.quick, child: icon),
        label: AnimatedSwitcher(
          duration: context.motion.quick,
          child: Text(label, key: ValueKey(label)),
        ),
      ),
    );
  }
}

/// Check mark that draws itself.
class _Tick extends StatelessWidget {
  const _Tick({super.key});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: context.motion.standard,
    curve: context.motion.standardCurve,
    builder: (context, t, _) => CustomPaint(
      size: const Size.square(Space.x4 + Space.x1),
      painter: _TickPainter(
        t,
        IconTheme.of(context).color ?? context.colors.onPrimary,
      ),
    ),
  );
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * 0.15, s.height * 0.55)
      ..lineTo(s.width * 0.42, s.height * 0.8)
      ..lineTo(s.width * 0.88, s.height * 0.25);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter o) => o.t != t || o.color != color;
}

/// Star that fills with a 1 → 1.25 → 1 pop (M11).
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: MotionTokens.quick,
  );
  static final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 1),
  ]);

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.value ? 'Remove from favorites' : 'Add to favorites',
    isSelected: widget.value,
    onPressed: () {
      Haptics.select();
      if (!context.motion.reduced) _pop.forward(from: 0);
      widget.onChanged(!widget.value);
    },
    icon: ScaleTransition(
      scale: _scale.animate(
        CurvedAnimation(parent: _pop, curve: MotionTokens.quickCurve),
      ),
      child: Icon(
        widget.value ? AppIcon.starFilled : AppIcon.star,
        color: widget.value ? context.tokens.favorite : null,
      ),
    ),
  );
}
