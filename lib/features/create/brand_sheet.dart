import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/brand.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/app_icons.dart';
import '../result/actions.dart';
import 'qr_card.dart';

/// Opens the brand editor for [data]. Saves the kit and returns its style, or null if dismissed.
/// [website] pre-fills "From website" (the code's own link, when it has one).
Future<QrStyle?> showBrandSheet(
  BuildContext context, {
  required String data,
  required ContentType type,
  String? website,
}) => showModalBottomSheet<QrStyle>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.92,
    child: BrandSheet(data: data, type: type, website: website),
  ),
);

class BrandSheet extends ConsumerStatefulWidget {
  const BrandSheet({
    required this.data,
    required this.type,
    super.key,
    this.website,
  });
  final String data;
  final ContentType type;
  final String? website;

  @override
  ConsumerState<BrandSheet> createState() => _BrandSheetState();
}

class _BrandSheetState extends ConsumerState<BrandSheet> {
  late final BrandKit? _saved = ref.read(brandProvider);
  late Color _color =
      _saved?.color ?? TypeColors.of(widget.type, Brightness.light).strong;
  late Uint8List? _logo = _saved?.logo;
  late bool _rounded = _saved?.rounded ?? true;
  Color? _logoColor; // the logo's own colour, offered as the first swatch
  bool _busy = false;
  late final _hex = TextEditingController(text: _hexOf(_color));

  static String _hexOf(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color? _parseHex(String s) {
    final v = s.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) return null;
    return Color(0xFF000000 | int.parse(v, radix: 16));
  }

  BrandKit get _kit => BrandKit(color: _color, logo: _logo, rounded: _rounded);

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setColor(Color c) => setState(() {
    _color = c;
    _hex.text = _hexOf(c);
  });

  Future<void> _useLogo(Uint8List? raw, String failure) async {
    final logo = raw == null ? null : await shrinkLogo(raw);
    if (!mounted) return;
    if (logo == null) {
      setState(() => _busy = false);
      return snack(context, failure);
    }
    final colour = await dominantColor(logo);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logo = logo;
      _logoColor = colour;
    });
    _setColor(colour);
    Haptics.success();
  }

  Future<void> _fromPhotos() async {
    Haptics.select();
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    await _useLogo(await file.readAsBytes(), 'That image could not be read');
  }

  Future<void> _fromWebsite() async {
    Haptics.select();
    final site = await showDialog<String>(
      context: context,
      builder: (_) => _WebsiteDialog(initial: widget.website ?? ''),
    );
    if (site == null || site.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    await _useLogo(
      await fetchSiteLogo(site),
      'No logo found on that site. Try a photo of it instead',
    );
  }

  Future<void> _apply() async {
    Haptics.success();
    await ref.read(brandProvider.notifier).save(_kit);
    if (mounted) Navigator.of(context).pop(brandStyle(_kit));
  }

  @override
  Widget build(BuildContext context) {
    final ink = scannableInk(_color);
    final adjusted = ink.toARGB32() != _color.toARGB32();
    final swatches = <Color>{
      ?_logoColor,
      Palette.black,
      Palette.inkBlue,
      for (final t in ContentType.values)
        TypeColors.of(t, Brightness.light).strong,
    }.toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.x3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Brand', style: context.text.titleLarge),
                    ),
                    if (_busy)
                      const SizedBox.square(
                        dimension: Space.x5,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              Center(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: context.tokens.qrCard,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(Radii.card),
                      side: BorderSide(
                        color: context.colors.onSurface.withValues(
                          alpha: Opacities.hairline,
                        ),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.x2),
                    child: QrCode(
                      data: widget.data,
                      style: brandStyle(_kit),
                      size: 176,
                      semanticsLabel: 'Preview of your branded code',
                    ),
                  ),
                ),
              ),
              if (adjusted)
                Padding(
                  padding: const EdgeInsets.only(top: Space.x2),
                  child: Text(
                    'Darkened a little so phones can still read it',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: Space.x6),
              Text('Logo', style: context.text.titleSmall),
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _fromPhotos,
                    icon: const Icon(AppIcon.images),
                    label: const Text('From photos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _fromWebsite,
                    icon: const Icon(AppIcon.globe),
                    label: const Text('From website'),
                  ),
                  if (_logo != null)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _logo = null;
                              _logoColor = null;
                            }),
                      icon: const Icon(AppIcon.close),
                      label: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: Space.x6),
              Text('Colour', style: context.text.titleSmall),
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: Space.x1,
                children: [
                  for (final c in swatches)
                    Semantics(
                      button: true,
                      selected: c.toARGB32() == _color.toARGB32(),
                      label: c == _logoColor
                          ? 'Colour from logo'
                          : 'Colour ${_hexOf(c)}',
                      child: InkResponse(
                        radius: Space.x6,
                        onTap: () {
                          Haptics.select();
                          _setColor(c);
                        },
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
                                  width: 2,
                                  color: c.toARGB32() == _color.toARGB32()
                                      ? context.colors.onSurface
                                      : context.colors.surface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.x3),
              TextField(
                controller: _hex,
                decoration: const InputDecoration(labelText: 'Hex colour'),
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) {
                  final c = _parseHex(v);
                  if (c != null) setState(() => _color = c);
                },
              ),
              const SizedBox(height: Space.x6),
              Text('Shape', style: context.text.titleSmall),
              const SizedBox(height: Space.x2),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('Dots')),
                  ButtonSegment(value: false, label: Text('Squares')),
                ],
                selected: {_rounded},
                onSelectionChanged: (s) {
                  Haptics.select();
                  setState(() => _rounded = s.first);
                },
              ),
              const SizedBox(height: Space.x6),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x2,
              Space.gutter,
              Space.x4,
            ),
            child: FilledButton(
              onPressed: _busy ? null : _apply,
              child: const Text('Use this brand'),
            ),
          ),
        ),
      ],
    );
  }
}

class _WebsiteDialog extends StatefulWidget {
  const _WebsiteDialog({required this.initial});
  final String initial;

  @override
  State<_WebsiteDialog> createState() => _WebsiteDialogState();
}

class _WebsiteDialogState extends State<_WebsiteDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Logo from a website'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Website address'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        const SizedBox(height: Space.x3),
        Text(
          "ScanLight downloads the site's icon directly from that website",
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _c.text),
        child: const Text('Find logo'),
      ),
    ],
  );
}
