import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/progress.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// First code of a new type: a "New in your collection" pill drops in at the top, holds, and
/// fades. Under reduced motion it just appears and fades.
void celebrateUnlock(BuildContext context, ContentType type) {
  final found = ProviderScope.containerOf(
    context,
  ).read(progressProvider).found.length;
  Haptics.success();
  SemanticsService.sendAnnouncement(
    View.of(context),
    'New in your collection: ${typeLabel(type)}, $found of ${ContentType.values.length}',
    Directionality.of(context),
  );
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(
      type: type,
      found: found,
      reduced: context.motion.reduced,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.type,
    required this.found,
    required this.reduced,
    required this.onDone,
  });
  final ContentType type;
  final int found;
  final bool reduced;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: MotionTokens.celebrate,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = context.hue(widget.type);
    final top = MediaQuery.paddingOf(context).top + Space.x4;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Pill: springs in over the first 15%, holds, fades over the last 15%.
          final inT = widget.reduced
              ? 1.0
              : MotionTokens.springCurve.transform((t / 0.15).clamp(0, 1));
          final out = ((1 - t) / 0.15).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned(
                top: top,
                left: Space.gutter,
                right: Space.gutter,
                child: Center(
                  child: Opacity(
                    opacity: out,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -Space.x3 * (1 - inT),
                      ), // rises a few pixels, no fall
                      child: Transform.scale(
                        scale: 1,
                        child: Material(
                          color: h.strong,
                          elevation: 6,
                          shape: const StadiumBorder(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.x2,
                              Space.x2,
                              Space.x6,
                              Space.x2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: Space.x10,
                                  height: Space.x10,
                                  decoration: BoxDecoration(
                                    color: h.onStrong,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    typeIcon(widget.type),
                                    color: h.strong,
                                    size: Space.x6,
                                  ),
                                ),
                                const SizedBox(width: Space.x3),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'New in your collection',
                                        style: context.text.labelMedium
                                            ?.copyWith(color: h.onStrong),
                                      ),
                                      Text(
                                        '${typeLabel(widget.type)} · ${widget.found} of ${ContentType.values.length}',
                                        style: context.text.titleMedium
                                            ?.copyWith(color: h.onStrong),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
