import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/brand.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../result/actions.dart';
import '../../ui/app_icons.dart';

class QrStyle {
  const QrStyle({
    this.fg,
    this.bg,
    this.ec = QrErrorCorrectLevel.M,
    this.rounded = false,
    this.centerIcon,
    this.logo,
  });
  final Color? fg, bg; // null = default black on white
  final int ec;
  final bool rounded;
  // Drawn over the middle; either one forces high error correction so the code still reads.
  final IconData? centerIcon;
  final Uint8List? logo;

  bool get coversCentre => centerIcon != null || logo != null;

  QrStyle copyWith({Color? fg, Color? bg, int? ec, bool? rounded}) => QrStyle(
    fg: fg ?? this.fg,
    bg: bg ?? this.bg,
    ec: ec ?? this.ec,
    rounded: rounded ?? this.rounded,
    centerIcon: centerIcon,
    logo: logo,
  );
}

/// A saved brand kit as a code style.
QrStyle brandStyle(BrandKit kit) => QrStyle(
  fg: scannableInk(kit.color),
  rounded: kit.rounded,
  ec: QrErrorCorrectLevel.H,
  logo: kit.logo,
);

/// Named looks for a code. Colours come from the type's light palette, because codes sit on white.
enum QrPreset { classic, dots, colour, badge, ink }

QrStyle presetStyle(QrPreset p, ContentType type) {
  final strong = TypeColors.of(type, Brightness.light).strong;
  return switch (p) {
    QrPreset.classic => const QrStyle(),
    QrPreset.dots => const QrStyle(rounded: true),
    QrPreset.colour => QrStyle(fg: strong, rounded: true),
    QrPreset.badge => QrStyle(
      fg: strong,
      rounded: true,
      ec: QrErrorCorrectLevel.H,
      centerIcon: typeIcon(type),
    ),
    QrPreset.ink => const QrStyle(fg: Palette.inkBlue, rounded: true),
  };
}

String presetLabel(QrPreset p) => switch (p) {
  QrPreset.classic => 'Classic',
  QrPreset.dots => 'Dots',
  QrPreset.colour => 'Colour',
  QrPreset.badge => 'Badge',
  QrPreset.ink => 'Ink',
};

/// The code itself: QR plus the optional centre icon on a white disc.
class QrCode extends StatelessWidget {
  const QrCode({
    required this.data,
    required this.style,
    required this.size,
    super.key,
    this.semanticsLabel = 'QR code',
    this.quietZone = Space.x6,
  });
  final String data;
  final QrStyle style;
  final double size, quietZone;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = style.fg ?? t.cameraScrim;
    final bg = style.bg ?? t.qrCard;
    return Stack(
      alignment: Alignment.center,
      children: [
        QrImageView(
          data: data,
          size: size,
          padding: EdgeInsets.all(quietZone),
          backgroundColor: bg,
          errorCorrectionLevel: style.coversCentre
              ? QrErrorCorrectLevel.H
              : style.ec,
          eyeStyle: QrEyeStyle(
            eyeShape: style.rounded ? QrEyeShape.circle : QrEyeShape.square,
            color: fg,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: style.rounded
                ? QrDataModuleShape.circle
                : QrDataModuleShape.square,
            color: fg,
          ),
          semanticsLabel: semanticsLabel,
        ),
        if (style.centerIcon != null)
          Container(
            width: size * 0.2,
            height: size * 0.2,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: fg, width: size * 0.012),
            ),
            child: Icon(style.centerIcon, color: fg, size: size * 0.11),
          ),
        // A logo sits on a background-coloured tile: about 5% of the area, well inside what
        // high error correction recovers (30%).
        if (style.logo != null)
          Container(
            width: size * 0.24,
            height: size * 0.24,
            padding: EdgeInsets.all(size * 0.02),
            decoration: ShapeDecoration(
              color: bg,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(size * 0.05),
              ),
            ),
            child: Image.memory(
              style.logo!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
      ],
    );
  }
}

/// The share card: type header, the code, title and excerpt, and an optional "Made with ScanLight"
/// footer. It is always white so the code scans. [boundaryKey] wraps only the code (saved to the
/// gallery, best for printing); [cardKey] wraps the whole card (what Share sends).
class QrCard extends StatelessWidget {
  const QrCard({
    required this.data,
    required this.boundaryKey,
    super.key,
    this.cardKey,
    this.type,
    this.label,
    this.excerpt,
    this.style = const QrStyle(),
    this.size = 240,
    this.branded = false,
  });
  final String data;
  final GlobalKey boundaryKey;
  final GlobalKey? cardKey;
  final ContentType? type;
  final String? label, excerpt;
  final QrStyle style;
  final double size;
  final bool branded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The card is always white, so its text uses the light scheme's ink.
    const ink = lightScheme;
    final h = type == null ? null : TypeColors.of(type!, Brightness.light);
    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: t.qrCard,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (h != null)
              SizedBox(
                width: size,
                child: Row(
                  children: [
                    Container(
                      width: Space.x8,
                      height: Space.x8,
                      decoration: BoxDecoration(
                        color: h.strong,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        typeIcon(type!),
                        size: Space.x4 + Space.x1,
                        color: h.onStrong,
                      ),
                    ),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Text(
                        typeLabel(type!),
                        style: context.text.titleSmall?.copyWith(
                          color: h.onContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            RepaintBoundary(
              key: boundaryKey,
              child: QrCode(
                data: data,
                style: style,
                size: size,
                semanticsLabel: 'QR code${label == null ? '' : ' for $label'}',
              ),
            ),
            if (label != null)
              SizedBox(
                width: size,
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium?.copyWith(
                    color: ink.onSurface,
                  ),
                ),
              ),
            if (excerpt != null)
              SizedBox(
                width: size,
                child: Text(
                  excerpt!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: ink.onSurfaceVariant,
                  ),
                ),
              ),
            if (branded) ...[
              const SizedBox(height: Space.x3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Brackets(
                    color: ink.primary,
                    arm: Space.x1 + 1,
                    stroke: 1.5,
                    child: const SizedBox.square(dimension: Space.x4),
                  ),
                  const SizedBox(width: Space.x1),
                  Text(
                    'Made with ScanLight',
                    style: context.text.labelMedium?.copyWith(
                      color: ink.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    // A hairline edge outside the boundary, so the shared PNG stays clean and the white card
    // still reads against a light page.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
          side: BorderSide(
            color: Palette.black.withValues(alpha: Opacities.hairline),
          ),
        ),
      ),
      child: RepaintBoundary(key: cardKey, child: card),
    );
  }
}

/// Row of style tiles, each a live mini code in that look, ending with the saved Brand kit
/// (or an empty Brand tile that opens the brand editor).
class QrPresetPicker extends ConsumerWidget {
  const QrPresetPicker({
    required this.type,
    required this.selected,
    required this.onChanged,
    required this.onBrand,
    super.key,
    this.brandSelected = false,
    this.edge = Space.gutter,
  });
  final ContentType type;
  final QrPreset? selected;
  final ValueChanged<QrPreset> onChanged;
  final VoidCallback onBrand;
  final bool brandSelected;
  final double edge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(brandProvider);
    Widget tile(
      String label,
      bool on,
      VoidCallback onTap,
      Widget face,
    ) => Padding(
      padding: const EdgeInsets.only(right: Space.x2),
      child: Semantics(
        button: true,
        selected: on,
        label: '$label style',
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button),
          onTap: () {
            Haptics.select();
            onTap();
          },
          child: ExcludeSemantics(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: context.motion.quick,
                  padding: const EdgeInsets.all(Space.x1),
                  decoration: ShapeDecoration(
                    color: context.tokens.qrCard,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                      side: BorderSide(
                        width:
                            2, // same width either way so the tile never shifts
                        color: on
                            ? context.hue(type).strong
                            : context.colors.outlineVariant,
                      ),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: Space.control - Space.x2,
                    child: face,
                  ),
                ),
                const SizedBox(height: Space.x1),
                Text(label, style: context.text.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
    Widget mini(QrStyle style) => QrCode(
      data: 'ScanLight',
      style: style,
      size: Space.control - Space.x2,
      quietZone: Space.x1,
    );
    return SizedBox(
      height: Space.control + Space.x12,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: edge),
        children: [
          for (final p in QrPreset.values)
            tile(
              presetLabel(p),
              p == selected && !brandSelected,
              () => onChanged(p),
              mini(presetStyle(p, type)),
            ),
          tile(
            'Brand',
            brandSelected,
            onBrand,
            kit == null
                ? Icon(AppIcon.stamp, color: lightScheme.onSurfaceVariant)
                : mini(brandStyle(kit)),
          ),
        ],
      ),
    );
  }
}

/// Renders the boundary to a 1024 px PNG.
Future<Uint8List> renderQrPng(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1024 / boundary.size.width);
  return (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

Future<File> _tempPng(Uint8List bytes, String name) async => File(
  '${(await getTemporaryDirectory()).path}/scanlight-$name.png',
).writeAsBytes(bytes);

Future<void> shareQr(GlobalKey key, String name) async {
  Haptics.select();
  final file = await _tempPng(await renderQrPng(key), name);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
  );
}

/// Saves to the gallery, then plays M10 (thumbnail flies to a "Saved" pill). Snackbar only under reduced motion.
Future<void> saveQr(BuildContext context, GlobalKey key, String name) async {
  try {
    final bytes = await renderQrPng(key);
    if (!await Gal.hasPermission(toAlbum: true)) {
      await Gal.requestPermission(toAlbum: true);
    }
    await Gal.putImage((await _tempPng(bytes, name)).path, album: 'ScanLight');
    Haptics.success();
    if (!context.mounted) return;
    if (context.motion.reduced) return snack(context, 'Saved to gallery');
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return snack(context, 'Saved to gallery');
    _flyToSaved(context, box.localToGlobal(Offset.zero) & box.size, bytes);
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Could not save. Check photo permissions.');
    }
  }
}

void _flyToSaved(BuildContext context, Rect from, Uint8List png) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) =>
        _SavedFlight(from: from, png: png, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _SavedFlight extends StatefulWidget {
  const _SavedFlight({
    required this.from,
    required this.png,
    required this.onDone,
  });
  final Rect from;
  final Uint8List png;
  final VoidCallback onDone;

  @override
  State<_SavedFlight> createState() => _SavedFlightState();
}

class _SavedFlightState extends State<_SavedFlight>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: MotionTokens.slow + MotionTokens.savedPill,
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
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top + Space.x4;
    final pill = Rect.fromCenter(
      center: Offset(size.width / 2, top + Space.x6),
      width: Space.x8,
      height: Space.x8,
    );
    final flightEnd =
        MotionTokens.slow.inMilliseconds / _c.duration!.inMilliseconds;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final f = MotionTokens.standardCurve.transform(
            (_c.value / flightEnd).clamp(0, 1),
          );
          final rect = Rect.lerp(widget.from, pill, f)!;
          final pillIn = ((_c.value - flightEnd * 0.8) / 0.1).clamp(0.0, 1.0);
          final pillOut = ((1 - _c.value) / 0.15).clamp(0.0, 1.0);
          return Stack(
            children: [
              if (f < 1)
                Positioned.fromRect(
                  rect: rect,
                  child: Opacity(
                    opacity: 1 - f * 0.6,
                    child: Image.memory(widget.png, fit: BoxFit.contain),
                  ),
                ),
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: pillIn * pillOut,
                    child: Material(
                      color: context.colors.inverseSurface,
                      shape: const StadiumBorder(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.x4,
                          vertical: Space.x3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcon.checkCircle,
                              color: context.colors.inversePrimary,
                              size: Space.x6 - Space.x1,
                            ),
                            const SizedBox(width: Space.x2),
                            Text(
                              'Saved to gallery',
                              style: context.text.labelLarge?.copyWith(
                                color: context.colors.onInverseSurface,
                              ),
                            ),
                          ],
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
