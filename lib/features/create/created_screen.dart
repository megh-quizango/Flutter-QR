import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/responsive.dart';
import '../../ui/widgets.dart';
import '../result/result_widgets.dart';
import 'brand_sheet.dart';
import 'qr_card.dart';
import '../../ui/app_icons.dart';

class CreatedScreen extends ConsumerStatefulWidget {
  const CreatedScreen({required this.record, super.key});
  final ScanRecord record;

  @override
  ConsumerState<CreatedScreen> createState() => _CreatedScreenState();
}

class _CreatedScreenState extends ConsumerState<CreatedScreen> {
  final _qrKey = GlobalKey();
  final _cardKey = GlobalKey();
  QrPreset? _preset = QrPreset.colour; // null once colours are customised
  late QrStyle _style = presetStyle(QrPreset.colour, widget.record.type);

  bool _brand = false; // the Brand tile is the chosen look

  void _custom(QrStyle s) => setState(() {
    _preset = null;
    _brand = false;
    _style = s;
  });

  /// First tap applies the saved brand; tapping it again (or with none saved) edits it.
  Future<void> _onBrand() async {
    final r = widget.record;
    final kit = ref.read(brandProvider);
    if (kit != null && !_brand) {
      return setState(() {
        _brand = true;
        _style = brandStyle(kit);
      });
    }
    final style = await showBrandSheet(
      context,
      data: r.rawValue,
      type: r.type,
      website: r.type == ContentType.url ? r.parsed['url'] as String? : null,
    );
    if (style != null && mounted) {
      setState(() {
        _brand = true;
        _style = style;
      });
    }
  }

  String get _name => widget.record.id.substring(0, 8);

  Widget _swatches(String label, Color selected, ValueChanged<Color> onPick) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelLarge),
          const SizedBox(height: Space.x2),
          Wrap(
            spacing: Space.x1,
            children: [
              for (final c in context.tokens.qrChoices)
                Semantics(
                  label: '$label colour',
                  selected: c == selected,
                  button: true,
                  child: InkResponse(
                    onTap: () {
                      Haptics.select();
                      onPick(c);
                    },
                    radius: Space.x6,
                    child: SizedBox.square(
                      dimension: Space.tap,
                      child: Center(
                        child: AnimatedContainer(
                          duration: context.motion.quick,
                          width: Space.x8,
                          height: Space.x8,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: c == selected ? 3 : 1,
                              color: c == selected
                                  ? context.colors.primary
                                  : context.colors.outline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = _style.fg ?? t.cameraScrim;
    final bg = _style.bg ?? t.qrCard;
    final lowContrast =
        contrastRatio(fg, bg) < 4 ||
        fg.computeLuminance() > bg.computeLuminance();
    final r = widget.record;
    final card = Center(
      child: QrCard(
        data: r.rawValue,
        boundaryKey: _qrKey,
        cardKey: _cardKey,
        type: r.type,
        label: r.title,
        excerpt: recordSummary(r),
        style: _style,
        branded: ref.watch(settingsProvider).brandedShare,
      ),
    );
    final controls = <Widget>[
      const SizedBox(height: Space.x4),
      QrPresetPicker(
        type: r.type,
        selected: _preset,
        brandSelected: _brand,
        edge: 0, // the list already has the gutter
        onBrand: _onBrand,
        onChanged: (p) => setState(() {
          _preset = p;
          _brand = false;
          _style = presetStyle(p, r.type);
        }),
      ),
      AnimatedSize(
        duration: context.motion.quick,
        child: lowContrast
            ? Padding(
                padding: const EdgeInsets.only(top: Space.x4),
                child: Row(
                  children: [
                    Icon(AppIcon.warning, color: t.warning),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Text(
                        'Low contrast: some scanners may not read this. Use a dark colour on a light background.',
                        style: context.text.bodyMedium?.copyWith(
                          color: t.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: Space.x6),
      SizedBox(
        height: Space.control,
        child: ActionButton(
          primary: true,
          icon: const Icon(AppIcon.download),
          label: const Text('Save to gallery'),
          onPressed: () => saveQr(context, _qrKey, _name),
        ),
      ),
      const SizedBox(height: Space.x3),
      Wrap(
        spacing: Space.x2,
        runSpacing: Space.x2,
        children: [
          ActionButton(
            icon: const Icon(AppIcon.share),
            label: const Text('Share image'),
            onPressed: () => shareQr(_cardKey, _name),
          ),
          CopyButton(text: r.rawValue, label: 'Copy content'),
        ],
      ),
      const SizedBox(height: Space.x2),
      ExpansionTile(
        title: Text('More options', style: context.text.titleSmall),
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expansionAnimationStyle: AnimationStyle(
          duration: context.motion.standard,
          curve: context.motion.standardCurve,
        ),
        children: [
          _swatches('Foreground', fg, (c) => _custom(_style.copyWith(fg: c))),
          const SizedBox(height: Space.x3),
          _swatches('Background', bg, (c) => _custom(_style.copyWith(bg: c))),
          const SizedBox(height: Space.x3),
          Text('Error correction', style: context.text.labelLarge),
          const SizedBox(height: Space.x2),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: QrErrorCorrectLevel.L, label: Text('L')),
              ButtonSegment(value: QrErrorCorrectLevel.M, label: Text('M')),
              ButtonSegment(value: QrErrorCorrectLevel.Q, label: Text('Q')),
              ButtonSegment(value: QrErrorCorrectLevel.H, label: Text('H')),
            ],
            selected: {
              _style.centerIcon != null ? QrErrorCorrectLevel.H : _style.ec,
            },
            onSelectionChanged: (s) => _custom(_style.copyWith(ec: s.first)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rounded style'),
            value: _style.rounded,
            onChanged: (b) => _custom(_style.copyWith(rounded: b)),
          ),
        ],
      ),
    ];
    return Theme(
      data: context.typedTheme(r.type),
      child: Scaffold(
        appBar: AppBar(
          title: Text(typeLabel(r.type)),
          titleSpacing:
              NavigationToolbar.kMiddleSpacing +
              sideInset(context, ContentWidth.wide),
        ),
        body: MaxWidth(
          ContentWidth.wide,
          child: context.windowSize == WindowSize.expanded
              // Wide: the code stays in view on the left while you style it on the right.
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(Space.x8),
                        child: card,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          Space.x4,
                          Space.x4,
                          Space.x8,
                          Space.x8,
                        ),
                        children: controls,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x4,
                    Space.gutter,
                    Space.x8,
                  ),
                  children: [card, ...controls],
                ),
        ),
      ),
    );
  }
}
