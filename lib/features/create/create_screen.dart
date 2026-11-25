import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/parser/payload_encoder.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import 'create_sheet.dart';
import 'qr_card.dart';
import '../../ui/responsive.dart';

const _blurbs = {
  ContentType.text: 'Any note or message',
  ContentType.url: 'Link to a website',
  ContentType.wifi: 'Let guests join',
  ContentType.contact: 'Share a contact card',
  ContentType.email: 'Pre-filled email',
  ContentType.phone: 'Tap to call',
  ContentType.sms: 'Pre-filled text',
};

/// About one card per 240 dp, 2 to 4 across; one column on a phone at large text so labels
/// never break mid-word.
int _columns(BuildContext context) {
  final width = math.min(MediaQuery.sizeOf(context).width, ContentWidth.wide);
  final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
  if (large && context.windowSize == WindowSize.compact) return 1;
  return (width / 240).floor().clamp(2, 4);
}

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MaxWidth(
      ContentWidth.wide,
      child: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('Create')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.x4,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Choose what the code opens, then style it and share or save it',
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.x8,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns(context),
                mainAxisSpacing: Space.x3,
                crossAxisSpacing: Space.x3,
                // badge + padding are fixed; the two text lines grow with text scale
                mainAxisExtent:
                    Space.x8 +
                    Space.x12 +
                    Space.x3 +
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(Space.x12 + Space.x4),
              ),
              delegate: SliverChildListDelegate([
                for (final t in PayloadEncoder.createTypes) _TypeCard(t),
              ]),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Type card: ripple on press, and it lifts (tonal step + scale) while held.
class _TypeCard extends StatefulWidget {
  const _TypeCard(this.type);
  final ContentType type;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = context.motion;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1, // press: a small step down, never a grow
      duration: m.instant,
      curve: m.instantCurve,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: () {
            Haptics.select();
            showCreateSheet(context, widget.type);
          },
          child: Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypeBadge(widget.type, size: Space.x10),
                    const Spacer(),
                    // A real code in this type's style: what you are about to make.
                    ExcludeSemantics(
                      child: QrCode(
                        data: typeLabel(widget.type),
                        style: presetStyle(QrPreset.colour, widget.type),
                        size: Space.x12,
                        quietZone: Space.x1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x4),
                Text(typeLabel(widget.type), style: context.text.titleMedium),
                Text(
                  _blurbs[widget.type]!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
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
