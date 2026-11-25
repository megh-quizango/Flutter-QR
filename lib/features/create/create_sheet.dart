import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/parser/payload_encoder.dart';
import '../../core/progress.dart';
import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/celebrate.dart';
import '../../ui/widgets.dart';
import '../result/result_widgets.dart';
import 'brand_sheet.dart';
import 'qr_card.dart';
import '../../ui/app_icons.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phoneRe = RegExp(r'^\+?[\d\s\-().]{3,}$');

String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
String? emailOrEmpty(String? v) =>
    (v ?? '').isEmpty || _emailRe.hasMatch(v!.trim())
    ? null
    : 'Enter a valid email';
String? phoneOrEmpty(String? v) =>
    (v ?? '').isEmpty || _phoneRe.hasMatch(v!.trim())
    ? null
    : 'Enter a valid phone number';

/// Adds https:// when missing; returns null if it is still not a web URL.
String? normalizeUrl(String v) {
  var s = v.trim();
  if (!s.contains('://')) s = 'https://$s';
  final u = Uri.tryParse(s);
  return u != null &&
          (u.scheme == 'http' || u.scheme == 'https') &&
          u.host.contains('.')
      ? s
      : null;
}

/// [initial] pre-fills the form from a parsed record ("Make one like this").
Future<void> showCreateSheet(
  BuildContext context,
  ContentType type, {
  Map<String, dynamic>? initial,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: AnimationStyle(
    duration: context.motion.standard,
    curve: context.motion.standardCurve,
    reverseDuration: context.motion.standard,
  ),
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.95,
    child: CreateSheet(type: type, initial: initial),
  ),
);

/// Form in a sheet with a live preview pinned on top (M9) and Share / Save in a bottom bar.
class CreateSheet extends ConsumerStatefulWidget {
  const CreateSheet({required this.type, super.key, this.initial});
  final ContentType type;
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<CreateSheet> {
  final _form = GlobalKey<FormState>();
  final _qrKey = GlobalKey();
  final _cardKey = GlobalKey();
  QrPreset _preset = QrPreset.colour;
  QrStyle? _brand; // set while the Brand tile is the chosen look
  final _c = <String, TextEditingController>{};
  String _security = 'WPA';
  bool _hidden = false;
  String? _preview; // payload shown in the preview, debounced
  Timer? _debounce;
  ScanRecord? _record; // saved to history on the first Share/Save

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d == null) return;
    String s(String k) => d[k] as String? ?? '';
    String first(String k) => (d[k] as List?)?.cast<String>().firstOrNull ?? '';
    final fill = switch (widget.type) {
      ContentType.text => {'text': s('text')},
      ContentType.url => {'url': s('url')},
      ContentType.wifi => {'ssid': s('ssid'), 'password': s('password')},
      ContentType.contact => {
        'name': s('name'),
        'phone': first('phones'),
        'email': first('emails'),
        'org': s('org'),
      },
      ContentType.email => {
        'to': s('to'),
        'subject': s('subject'),
        'body': s('body'),
      },
      ContentType.phone => {'number': s('number')},
      ContentType.sms => {'number': s('number'), 'body': s('body')},
      _ => const <String, String>{},
    };
    if (widget.type == ContentType.wifi) {
      _security = switch (s('security')) {
        'WEP' => 'WEP',
        'nopass' || '' => s('password').isEmpty ? 'nopass' : 'WPA',
        _ => 'WPA',
      };
      _hidden = d['hidden'] == true;
    }
    fill.forEach((k, v) => c(k).text = v);
  }

  TextEditingController c(String k) =>
      _c.putIfAbsent(k, () => TextEditingController()..addListener(_changed));
  String v(String k) => c(k).text.trim();

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(MotionTokens.previewDebounce, () {
      if (!mounted) return;
      final next = _hasInput()
          ? PayloadEncoder.encode(widget.type, _data())
          : null;
      if (next != _preview) setState(() => _preview = next);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  /// Enough input to draw a meaningful preview (validation happens on Share/Save).
  bool _hasInput() => switch (widget.type) {
    ContentType.text => c('text').text.isNotEmpty,
    ContentType.url => normalizeUrl(v('url')) != null,
    ContentType.wifi => v('ssid').isNotEmpty,
    ContentType.contact => v('name').isNotEmpty,
    ContentType.email => v('to').isNotEmpty,
    ContentType.phone || ContentType.sms => v('number').isNotEmpty,
    _ => false,
  };

  Widget _field(
    String key,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.x4),
    child: TextFormField(
      controller: c(key),
      decoration: InputDecoration(labelText: label),
      validator: validator,
      keyboardType: keyboard,
      maxLines: maxLines,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
    ),
  );

  List<Widget> _fields() => switch (widget.type) {
    ContentType.text => [
      _field(
        'text',
        'Text',
        validator: required,
        keyboard: TextInputType.multiline,
        maxLines: 6,
      ),
    ],
    ContentType.url => [
      _field(
        'url',
        'Website address',
        keyboard: TextInputType.url,
        validator: (s) =>
            required(s) ??
            (normalizeUrl(s!) == null ? 'Enter a valid web address' : null),
      ),
    ],
    ContentType.wifi => [
      _field('ssid', 'Network name (SSID)', validator: required),
      Padding(
        padding: const EdgeInsets.only(bottom: Space.x4),
        child: DropdownButtonFormField<String>(
          initialValue: _security,
          decoration: const InputDecoration(labelText: 'Security'),
          items: const [
            DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2/WPA3')),
            DropdownMenuItem(value: 'WEP', child: Text('WEP')),
            DropdownMenuItem(value: 'nopass', child: Text('None (open)')),
          ],
          onChanged: (s) {
            setState(() => _security = s!);
            _changed();
          },
        ),
      ),
      if (_security != 'nopass')
        _field('password', 'Password', validator: required),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hidden network'),
        value: _hidden,
        onChanged: (b) {
          setState(() => _hidden = b);
          _changed();
        },
      ),
    ],
    ContentType.contact => [
      _field('name', 'Name', validator: required),
      _field(
        'phone',
        'Phone',
        keyboard: TextInputType.phone,
        validator: phoneOrEmpty,
      ),
      _field(
        'email',
        'Email',
        keyboard: TextInputType.emailAddress,
        validator: emailOrEmpty,
      ),
      _field('org', 'Organisation'),
    ],
    ContentType.email => [
      _field(
        'to',
        'To',
        keyboard: TextInputType.emailAddress,
        validator: (s) => required(s) ?? emailOrEmpty(s),
      ),
      _field('subject', 'Subject'),
      _field('body', 'Message', keyboard: TextInputType.multiline, maxLines: 4),
    ],
    ContentType.phone => [
      _field(
        'number',
        'Phone number',
        keyboard: TextInputType.phone,
        validator: (s) => required(s) ?? phoneOrEmpty(s),
      ),
    ],
    ContentType.sms => [
      _field(
        'number',
        'Phone number',
        keyboard: TextInputType.phone,
        validator: (s) => required(s) ?? phoneOrEmpty(s),
      ),
      _field('body', 'Message', keyboard: TextInputType.multiline, maxLines: 4),
    ],
    _ => [],
  };

  Map<String, dynamic> _data() => switch (widget.type) {
    ContentType.text => {'text': c('text').text},
    ContentType.url => {'url': normalizeUrl(v('url')) ?? ''},
    ContentType.wifi => {
      'ssid': c('ssid').text,
      'password': _security == 'nopass' ? '' : c('password').text,
      'security': _security,
      'hidden': _hidden,
    },
    ContentType.contact => {
      'name': v('name'),
      'phones': [if (v('phone').isNotEmpty) v('phone')],
      'emails': [if (v('email').isNotEmpty) v('email')],
      'org': v('org'),
    },
    ContentType.email => {
      'to': v('to'),
      'subject': v('subject'),
      'body': c('body').text,
    },
    ContentType.phone => {'number': v('number').replaceAll(' ', '')},
    ContentType.sms => {
      'number': v('number').replaceAll(' ', ''),
      'body': c('body').text,
    },
    _ => {},
  };

  /// Validates, makes sure the preview shows the final payload, and saves it to history once (R-CRE-6).
  Future<ScanRecord?> _commit() async {
    if (!_form.currentState!.validate()) return null;
    _debounce?.cancel();
    final raw = PayloadEncoder.encode(widget.type, _data());
    if (raw != _preview) {
      setState(() => _preview = raw);
      await WidgetsBinding
          .instance
          .endOfFrame; // let the boundary repaint before rendering it
    }
    if (_record?.rawValue != raw) {
      _record = buildRecord(raw, 'qrCode', ScanSource.created);
      await ref.read(repoProvider).save(_record!);
      final isNew = await ref.read(progressProvider.notifier).log(widget.type);
      if (isNew && mounted) celebrateUnlock(context, widget.type);
    }
    return _record;
  }

  @override
  Widget build(BuildContext context) {
    final m = context.motion;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.x3,
          ),
          child: Row(
            children: [
              TypeBadge(widget.type, size: Space.x8 + Space.x2),
              const SizedBox(width: Space.x3),
              Text(
                '${typeLabel(widget.type)} QR code',
                style: context.text.titleLarge,
              ),
            ],
          ),
        ),
        // Pinned live preview; cross-fades on change (M9).
        AnimatedSwitcher(
          duration: m.quick,
          switchInCurve: m.quickCurve,
          child: _preview == null
              ? SizedBox(
                  key: const ValueKey('empty'),
                  height: 160 + Space.x8 * 2,
                  child: Center(
                    child: Text(
                      'Fill in the form to see your code',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : QrCard(
                  key: ValueKey(_preview),
                  data: _preview!,
                  boundaryKey: _qrKey,
                  cardKey: _cardKey,
                  type: widget.type,
                  style: _brand ?? presetStyle(_preset, widget.type),
                  branded: ref.watch(settingsProvider).brandedShare,
                  size: 160,
                ),
        ),
        const SizedBox(height: Space.x3),
        QrPresetPicker(
          type: widget.type,
          selected: _preset,
          brandSelected: _brand != null,
          onChanged: (p) => setState(() {
            _preset = p;
            _brand = null;
          }),
          onBrand: () async {
            final kit = ref.read(brandProvider);
            // First tap applies the saved brand; tapping it again (or with none saved) edits it.
            if (kit != null && _brand == null) {
              return setState(() => _brand = brandStyle(kit));
            }
            final style = await showBrandSheet(
              context,
              data: _preview ?? typeLabel(widget.type),
              type: widget.type,
              website: widget.type == ContentType.url ? v('url') : null,
            );
            if (style != null && mounted) setState(() => _brand = style);
          },
        ),
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: _fields(),
            ),
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
            child: Row(
              children: [
                Expanded(
                  child: ActionButton(
                    icon: const Icon(AppIcon.share),
                    label: const Text('Share'),
                    onPressed: () async {
                      final r = await _commit();
                      if (r != null) {
                        await shareQr(_cardKey, r.id.substring(0, 8));
                      }
                    },
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: SizedBox(
                    height: Space.control,
                    child: ActionButton(
                      primary: true,
                      icon: const Icon(AppIcon.download),
                      label: const Text('Save'),
                      onPressed: () async {
                        final r = await _commit();
                        if (r != null && context.mounted) {
                          await saveQr(context, _qrKey, r.id.substring(0, 8));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
