import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/parser/payload_encoder.dart';
import '../../core/parser/url_safety.dart';
import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';
import '../create/create_sheet.dart';
import 'actions.dart';
import 'result_widgets.dart';
import '../../ui/app_icons.dart';
import '../../ui/responsive.dart';

/// Result as a draggable sheet with 0.6 / 0.95 snap points, rising on a spring (M3).
Future<void> showResultSheet(BuildContext context, ScanRecord record) {
  final m = context.motion;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.tokens.clear,
    elevation: 0,
    showDragHandle: false,
    sheetAnimationStyle: AnimationStyle(
      duration: m.reduced ? Duration.zero : MotionTokens.slow,
      curve: MotionTokens.springCurve,
      reverseDuration: m.standard,
      reverseCurve: MotionTokens.standardCurve,
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.6, 0.95],
      snapAnimationDuration: context.motion.standard,
      builder: (context, controller) => DecoratedBox(
        decoration: ShapeDecoration(
          color: context.colors.surfaceContainerLow,
          shadows: context.tokens.sheetShadow,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Radii.sheet),
            ),
          ),
        ),
        child: ResultView(
          record: record,
          controller: controller,
          inSheet: true,
        ),
      ),
    ),
  );
}

/// Full-page result, used by the history container transform (M6).
class ResultScreen extends StatelessWidget {
  const ResultScreen({required this.record, super.key});
  final ScanRecord record;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(typeLabel(record.type)),
      titleSpacing:
          NavigationToolbar.kMiddleSpacing +
          sideInset(context, ContentWidth.form),
    ),
    body: MaxWidth(ContentWidth.form, child: ResultView(record: record)),
  );
}

class _Action {
  const _Action(this.label, this.icon, this.onTap, {this.copy});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? copy; // when set, renders a CopyButton for this text
}

class ResultView extends ConsumerStatefulWidget {
  const ResultView({
    required this.record,
    super.key,
    this.controller,
    this.inSheet = false,
  });
  final ScanRecord record;
  final ScrollController? controller;
  final bool inSheet;

  @override
  ConsumerState<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<ResultView> {
  ScanRecord get r => widget.record;
  Map<String, dynamic> get d => r.parsed;
  bool _saved = false;
  bool _favorite = false;
  bool _showPassword = false;
  bool _wifiFailed = false;
  bool _skipReveal = false; // a tap during M3 jumps to the end state
  late final Future<Product?>? _product = r.type == ContentType.product
      ? lookupProduct(d['code'] as String)
      : null;

  @override
  void initState() {
    super.initState();
    ref.read(repoProvider).get(r.id).then((saved) {
      if (mounted) {
        setState(() {
          _saved = saved != null;
          _favorite = saved?.favorite ?? false;
        });
      }
    });
  }

  List<_Action> _actions() {
    final inApp = ref.read(settingsProvider).inAppBrowser;
    final phones = (d['phones'] as List?)?.cast<String>() ?? const <String>[];
    final emails = (d['emails'] as List?)?.cast<String>() ?? const <String>[];
    final copyRaw = _Action('Copy', AppIcon.copy, null, copy: r.rawValue);
    final share = _Action('Share', AppIcon.share, () {
      Haptics.select();
      shareText(r.rawValue);
    });
    return [
      ...switch (r.type) {
        ContentType.url => [
          _Action(
            'Open',
            AppIcon.open,
            () => openUrl(context, d['url'] as String, inApp: inApp),
          ),
          _Action('Copy', AppIcon.copy, null, copy: d['url'] as String),
          share,
        ],
        ContentType.text => [
          _Action('Copy', AppIcon.copy, null, copy: r.rawValue),
          share,
          _Action(
            'Web search',
            AppIcon.search,
            () => webSearch(context, r.rawValue),
          ),
        ],
        ContentType.wifi => [
          const _Action(
            'Connect',
            AppIcon.wifi,
            null,
          ), // rendered as ConnectButton
          if ((d['password'] as String).isNotEmpty)
            _Action(
              'Copy password',
              AppIcon.key,
              null,
              copy: d['password'] as String,
            ),
          if (_wifiFailed)
            const _Action('Wi-Fi settings', AppIcon.settings, openWifiSettings),
        ],
        ContentType.contact => [
          _Action(
            'Add to contacts',
            AppIcon.userAdd,
            () => addContact(context, d),
          ),
          if (phones.isNotEmpty)
            _Action(
              'Call',
              AppIcon.phone,
              () => launch(context, Uri(scheme: 'tel', path: phones.first)),
            ),
          if (emails.isNotEmpty)
            _Action(
              'Email',
              AppIcon.mail,
              () => launch(context, Uri(scheme: 'mailto', path: emails.first)),
            ),
        ],
        ContentType.email => [
          _Action(
            'Compose',
            AppIcon.edit,
            () => launch(
              context,
              Uri.parse(
                'mailto:${d['to']}?subject=${Uri.encodeComponent(d['subject'] as String)}'
                '&body=${Uri.encodeComponent(d['body'] as String)}',
              ),
            ),
          ),
          copyRaw,
        ],
        ContentType.phone => [
          _Action(
            'Call',
            AppIcon.phone,
            () => launch(
              context,
              Uri(scheme: 'tel', path: d['number'] as String),
            ),
          ),
          _Action('Copy', AppIcon.copy, null, copy: d['number'] as String),
        ],
        ContentType.sms => [
          _Action(
            'Send SMS',
            AppIcon.message,
            () => launch(
              context,
              Uri.parse(
                'sms:${d['number']}?body=${Uri.encodeComponent(d['body'] as String)}',
              ),
            ),
          ),
          copyRaw,
        ],
        ContentType.geo => [
          _Action('Open in Maps', AppIcon.map, () => openMaps(context, d)),
          copyRaw,
        ],
        ContentType.event => [
          _Action(
            'Add to calendar',
            AppIcon.calendarAdd,
            () => addEvent(context, d),
          ),
          copyRaw,
        ],
        ContentType.product => [
          _Action(
            'Search web',
            AppIcon.search,
            () => webSearch(context, d['code'] as String),
          ),
          copyRaw,
        ],
      },
      if (r.source == ScanSource.created)
        _Action(
          'Show QR code',
          AppIcon.qr,
          () => context.push('/created', extra: r),
        ),
    ];
  }

  Widget _button(_Action a, {bool primary = false}) {
    if (a.copy != null) {
      return CopyButton(
        text: a.copy!,
        label: a.label,
        icon: a.icon,
        primary: primary,
      );
    }
    if (r.type == ContentType.wifi && a.label == 'Connect') {
      return ConnectButton(
        connect: () => connectWifi(d),
        onResult: (ok) => setState(() => _wifiFailed = !ok),
      );
    }
    return ActionButton(
      primary: primary,
      onPressed: a.onTap,
      icon: Icon(a.icon),
      label: Text(a.label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions();
    final warnings = r.type == ContentType.url
        ? urlWarnings(d['url'] as String)
        : const <String>[];
    final step = context.motion.revealStagger;
    Widget reveal(int i, Widget child) =>
        Reveal(index: i, step: step, skip: _skipReveal, child: child);

    final secondary = actions.skip(1).toList();
    final stackButtons =
        MediaQuery.textScalerOf(context).scale(1) > 1.3 || secondary.length > 2;
    final canRemake = PayloadEncoder.createTypes.contains(r.type);
    return Theme(
      data: context.typedTheme(r.type),
      child: Listener(
        onPointerDown: (_) {
          if (!_skipReveal) setState(() => _skipReveal = true);
        },
        child: ListView(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.x8,
          ),
          children: [
            if (widget.inSheet) const _DragHandle(),
            if (warnings.isNotEmpty) reveal(0, _WarningBanner(warnings)),
            reveal(0, _header(context)),
            const SizedBox(height: Space.x4),
            reveal(
              1,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.x4),
                  child: _content(context),
                ),
              ),
            ),
            if (_wifiFailed) ...[
              const SizedBox(height: Space.x3),
              _InlineStatus(
                icon: AppIcon.alert,
                color: context.colors.error,
                text:
                    'Could not join automatically. Copy the password and join in Wi-Fi settings.',
              ),
            ],
            const SizedBox(height: Space.x6),
            reveal(
              2,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: Space.control,
                    child: _button(actions.first, primary: true),
                  ),
                  if (secondary.isNotEmpty) const SizedBox(height: Space.x3),
                  if (stackButtons)
                    Wrap(
                      spacing: Space.x2,
                      runSpacing: Space.x2,
                      children: [for (final a in secondary) _button(a)],
                    )
                  else
                    Row(
                      children: [
                        for (final (i, a) in secondary.indexed) ...[
                          if (i > 0) const SizedBox(width: Space.x2),
                          Expanded(child: _button(a)),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            if (widget.inSheet || canRemake) ...[
              const SizedBox(height: Space.x3),
              Wrap(
                spacing: Space.x2,
                children: [
                  if (widget.inSheet)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(AppIcon.scan),
                      label: const Text('Scan another'),
                    ),
                  if (canRemake)
                    TextButton.icon(
                      onPressed: () {
                        Haptics.select();
                        showCreateSheet(context, r.type, initial: d);
                      },
                      icon: const Icon(AppIcon.remake),
                      label: const Text('Make one like this'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.x4),
            ExpansionTile(
              title: Text('Details', style: context.text.titleSmall),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: Space.x4),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              expansionAnimationStyle: AnimationStyle(
                duration: context.motion.standard,
                curve: context.motion.standardCurve,
              ),
              children: [
                _kv('Format', r.format),
                _kv('Source', r.source.name),
                _kv(
                  'Scanned',
                  '${MaterialLocalizations.of(context).formatFullDate(r.createdAt)} '
                      '${TimeOfDay.fromDateTime(r.createdAt).format(context)}',
                ),
                _kv('Raw value', r.rawValue, mono: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Header card: neutral, with the solid type badge as its one colour.
  Widget _header(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          Space.x4,
          Space.x1,
          Space.x4,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: context.colors.onSurfaceVariant),
          child: Row(
            children: [
              TypeBadge(r.type, size: Space.control, solid: true),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.merge(
                        r.type == ContentType.product ? tabular : null,
                      ),
                    ),
                    Text(
                      recordSummary(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_saved) ...[
                FavoriteButton(
                  value: _favorite,
                  onChanged: (v) {
                    setState(() => _favorite = v);
                    ref.read(repoProvider).setFavorite(r.id, v);
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(AppIcon.trash),
                  onPressed: () async {
                    await ref.read(repoProvider).delete([r.id]);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.x1 + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Text(
          v.isEmpty ? '—' : v,
          style: context.text.bodyLarge?.merge(mono ? tabular : null),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context) {
    final rows = <Widget>[];
    void add(String k, Object? v, {bool mono = false}) {
      final s = v is List ? v.join('\n') : (v?.toString() ?? '');
      if (s.isNotEmpty) rows.add(_kv(k, s, mono: mono));
    }

    switch (r.type) {
      case ContentType.url:
        add('Link', d['url']);
      case ContentType.text:
        add('Text', d['text']);
      case ContentType.wifi:
        add('Network', d['ssid']);
        add('Security', d['security'] == 'nopass' ? 'Open' : d['security']);
        if ((d['password'] as String).isNotEmpty) {
          rows.add(
            Row(
              children: [
                Expanded(
                  child: _kv(
                    'Password',
                    _showPassword ? d['password'] as String : '••••••••',
                    mono: true,
                  ),
                ),
                IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(_showPassword ? AppIcon.eyeOff : AppIcon.eye),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ],
            ),
          );
        }
        if (d['hidden'] == true) add('Hidden network', 'Yes');
      case ContentType.contact:
        add('Name', d['name']);
        add('Phone', d['phones'], mono: true);
        add('Email', d['emails']);
        add('Organisation', d['org']);
      case ContentType.email:
        add('To', d['to']);
        add('Subject', d['subject']);
        add('Message', d['body']);
      case ContentType.phone:
        add('Number', d['number'], mono: true);
      case ContentType.sms:
        add('Number', d['number'], mono: true);
        add('Message', d['body']);
      case ContentType.geo:
        add('Place', d['query']);
        add('Coordinates', '${d['lat']}, ${d['lng']}', mono: true);
      case ContentType.event:
        String fmt(Object? iso) {
          final t = DateTime.tryParse(iso as String? ?? '')?.toLocal();
          return t == null
              ? ''
              : '${MaterialLocalizations.of(context).formatMediumDate(t)} ${TimeOfDay.fromDateTime(t).format(context)}';
        }
        add('Title', d['title']);
        add('Starts', fmt(d['start']));
        add('Ends', fmt(d['end']));
        add('Location', d['location']);
      case ContentType.product:
        add('Code', d['code'], mono: true);
        rows.add(_ProductCard(_product!));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.future);
  final Future<Product?> future;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: future,
    builder: (context, snap) => AnimatedSwitcher(
      duration: context.motion.quick,
      child: switch (snap.connectionState) {
        ConnectionState.done when snap.data != null => ListTile(
          key: const ValueKey('p'),
          contentPadding: EdgeInsets.zero,
          leading: snap.data!.imageUrl == null
              ? null
              : ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(Radii.chip),
                  child: Image.network(
                    snap.data!.imageUrl!,
                    width: Space.control,
                    height: Space.control,
                    cacheWidth:
                        (Space.control * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(AppIcon.imageOff),
                  ),
                ),
          title: Text(snap.data!.name),
          subtitle: snap.data!.brand.isEmpty ? null : Text(snap.data!.brand),
        ),
        ConnectionState.done => const _InlineStatus(
          key: ValueKey('n'),
          icon: AppIcon.globe,
          text: 'No product details found. Try searching the web.',
        ),
        _ => const SizedBox(
          key: ValueKey('l'),
          height: Space.control + Space.x6,
          child: Skeleton(rows: 1),
        ),
      },
    ),
  );
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner(this.warnings);
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Card(
        color: t.warningContainer,
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcon.warning, color: t.onWarningContainer),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check this link before opening',
                      style: context.text.titleSmall?.copyWith(
                        color: t.onWarningContainer,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      warnings.join('\n'),
                      style: context.text.bodyMedium?.copyWith(
                        color: t.onWarningContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.text,
    super.key,
    this.color,
  });
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Space.x2),
      child: Row(
        children: [
          Icon(icon, size: Space.x6, color: c),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x3),
      child: Container(
        width: Space.x8,
        height: Space.x1,
        decoration: BoxDecoration(
          color: context.colors.onSurfaceVariant.withValues(
            alpha: Opacities.disabled,
          ),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),
  );
}
