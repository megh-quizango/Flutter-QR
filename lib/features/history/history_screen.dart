import 'dart:io';
import 'dart:isolate';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/db/scan_repository.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/line_art.dart';
import '../../ui/widgets.dart';
import '../result/actions.dart';
import '../result/result_screen.dart';
import '../../ui/app_icons.dart';
import '../../ui/responsive.dart';

String relativeTime(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// "Today", "Yesterday" or a date, for the sticky day headers.
String dayLabel(DateTime t, MaterialLocalizations l, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final days = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return l.formatMediumDate(t);
}

String toCsv(List<ScanRecord> records) {
  String cell(String s) => '"${s.replaceAll('"', '""')}"';
  return [
    'created_at,source,format,type,title,raw_value,favorite',
    for (final r in records)
      [
        r.createdAt.toIso8601String(),
        r.source.name,
        r.format,
        r.type.name,
        cell(r.title),
        cell(r.rawValue),
        r.favorite,
      ].join(','),
  ].join('\n');
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;
  String _search = '';
  final _selected = <String>{};
  final _hidden = <String>{}; // swiped away, hidden before the reload lands
  final _restored = <String>{}; // brought back by Undo; they animate back in
  bool _firstLoadDone = false;

  ScanRepository get _repo => ref.read(repoProvider);

  Future<void> _delete(List<ScanRecord> items) async {
    setState(() => _hidden.addAll(items.map((r) => r.id)));
    await _repo.delete(items.map((r) => r.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            items.length == 1 ? 'Deleted' : '${items.length} deleted',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final r in items) {
                await _repo.save(r);
              }
              if (mounted) {
                setState(() {
                  _hidden.removeAll(items.map((r) => r.id));
                  _restored.addAll(items.map((r) => r.id));
                });
              }
            },
          ),
        ),
      );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(AppIcon.trash),
        title: const Text('Clear all history?'),
        content: const Text(
          'This deletes every scanned and created code, including favorites. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok == true) await _repo.clear();
  }

  Future<void> _shareCsv() async {
    final records = await _repo.list();
    if (!mounted) return;
    if (records.isEmpty) return snack(context, 'Nothing to export');
    final csv = await Isolate.run(
      () => toCsv(records),
    ); // off the UI isolate (P-5)
    final file = File(
      '${(await getTemporaryDirectory()).path}/scanlight-history.csv',
    );
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(historyProvider((_filter, _search)));
    final items = (async.valueOrNull ?? const <ScanRecord>[])
        .where((r) => !_hidden.contains(r.id))
        .toList();
    final selecting = _selected.isNotEmpty;
    final animateIn = !_firstLoadDone;
    if (async.hasValue && !_firstLoadDone) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _firstLoadDone = true,
      );
    }

    // Group by calendar day, keeping newest-first order.
    final l = MaterialLocalizations.of(context);
    final groups = <String, List<ScanRecord>>{};
    for (final r in items) {
      groups.putIfAbsent(dayLabel(r.createdAt, l), () => []).add(r);
    }
    final offsets = <String, int>{};
    var running = 0;
    for (final g in groups.entries) {
      offsets[g.key] = running;
      running += g.value.length;
    }

    return Scaffold(
      body: MaxWidth(
        ContentWidth.list,
        child: CustomScrollView(
          slivers: [
            selecting ? _selectionBar(items) : _titleBar(),
            PinnedHeaderSliver(
              child: ColoredBox(
                color: context.colors.surface,
                child: _filters(),
              ),
            ),
            if (async.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(
                  art: Art.error,
                  title: 'History could not load',
                  action: FilledButton.tonal(
                    onPressed: () =>
                        ref.invalidate(historyProvider((_filter, _search))),
                    child: const Text('Try again'),
                  ),
                ),
              )
            else if (!async.hasValue)
              const SliverFillRemaining(child: Skeleton())
            else if (items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty())
            else
              for (final g in groups.entries)
                SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(child: _DayHeader(g.key)),
                    SliverList.builder(
                      itemCount: g.value.length,
                      itemBuilder: (context, i) {
                        final r = g.value[i];
                        final n = offsets[g.key]! + i;
                        final restored = _restored.contains(r.id);
                        return Reveal(
                          key: ValueKey(r.id),
                          index: restored ? 0 : n,
                          step: context.motion.listStagger,
                          // M7: only the first 10 on first load; Undo-restored items always.
                          skip: !restored && (!animateIn || n >= 10),
                          child: _HistoryTile(
                            record: r,
                            selecting: selecting,
                            selected: _selected.contains(r.id),
                            onToggle: () => setState(
                              () => _selected.contains(r.id)
                                  ? _selected.remove(r.id)
                                  : _selected.add(r.id),
                            ),
                            onDismissed: () => _delete([r]),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x8)),
          ],
        ),
      ),
    );
  }

  Widget _titleBar() => SliverAppBar.medium(
    title: const Text('History'),
    actions: [
      PopupMenuButton<String>(
        tooltip: 'More options',
        icon: const Icon(AppIcon.more),
        onSelected: (v) {
          if (v == 'csv') _shareCsv();
          if (v == 'clear') _clearAll();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'csv',
            child: ListTile(
              leading: Icon(AppIcon.export),
              title: Text('Export as CSV'),
            ),
          ),
          PopupMenuItem(
            value: 'clear',
            child: ListTile(
              leading: Icon(AppIcon.trash),
              title: Text('Clear all'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _selectionBar(List<ScanRecord> items) {
    final chosen = items.where((r) => _selected.contains(r.id)).toList();
    return SliverAppBar(
      pinned: true,
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(AppIcon.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Share selected',
          icon: const Icon(AppIcon.share),
          onPressed: () =>
              shareText(chosen.map((r) => r.rawValue).join('\n\n')),
        ),
        IconButton(
          tooltip: 'Delete selected',
          icon: const Icon(AppIcon.trash),
          onPressed: () {
            setState(_selected.clear);
            _delete(chosen);
          },
        ),
      ],
    );
  }

  Widget _filters() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x2,
          Space.gutter,
          Space.x2,
        ),
        child: TextField(
          decoration: const InputDecoration(
            hintText: 'Search history',
            prefixIcon: Icon(AppIcon.search),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      SizedBox(
        height: Space.tap,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          children: [
            for (final (f, label) in [
              (HistoryFilter.all, 'All'),
              (HistoryFilter.scanned, 'Scanned'),
              (HistoryFilter.created, 'Created'),
              (HistoryFilter.favorites, 'Favorites'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: Space.x2),
                child: FilterChip(
                  label: Text(label),
                  selected: _filter == f,
                  onSelected: (_) {
                    Haptics.select();
                    setState(() => _filter = f);
                  },
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _empty() => StatusView(
    art: Art.history,
    float: true,
    title: _search.isEmpty && _filter == HistoryFilter.all
        ? 'No scans yet'
        : 'Nothing matches',
    body: _search.isEmpty && _filter == HistoryFilter.all
        ? 'Codes you scan or create appear here.'
        : 'Try another search or filter.',
    action: FilledButton.tonal(
      onPressed: () => goTab(context, ref, 0),
      child: const Text('Scan a code'),
    ),
  );
}

class _HistoryTile extends StatefulWidget {
  const _HistoryTile({
    required this.record,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onDismissed,
  });
  final ScanRecord record;
  final bool selecting, selected;
  final VoidCallback onToggle, onDismissed;

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final m = context.motion;
    return Dismissible(
      key: ValueKey(r.id),
      direction: widget.selecting
          ? DismissDirection.none
          : DismissDirection.endToStart,
      movementDuration: m.standard,
      resizeDuration: m.reduced
          ? null
          : m.standard, // M8: collapse height, or remove instantly
      onUpdate: (d) {
        if (d.reached && !d.previousReached) Haptics.success();
        setState(() => _progress = d.progress);
      },
      background: ColoredBox(
        color: context.colors.errorContainer,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: Space.x6),
            child: Transform.scale(
              scale: 0.6 + 0.8 * _progress.clamp(0, 0.5),
              child: Icon(
                AppIcon.trash,
                color: context.colors.onErrorContainer,
                semanticLabel: 'Delete',
              ),
            ),
          ),
        ),
      ),
      onDismissed: (_) => widget.onDismissed(),
      child: OpenContainer<void>(
        // M6 container transform; a plain fade under reduced motion.
        transitionType: m.reduced
            ? ContainerTransitionType.fadeThrough
            : ContainerTransitionType.fade,
        transitionDuration: m.fade,
        closedElevation: 0,
        openElevation: 0,
        closedColor: context.tokens.clear,
        openColor: context.colors.surface,
        middleColor: context.colors.surface,
        closedShape: const RoundedRectangleBorder(),
        tappable: false,
        openBuilder: (_, _) => ResultScreen(record: r),
        closedBuilder: (context, open) => ListTile(
          selected: widget.selected,
          leading: AnimatedSwitcher(
            duration: m.quick,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: widget.selecting
                ? SizedBox.square(
                    key: const ValueKey('check'),
                    dimension: Space.tap,
                    child: Checkbox(
                      value: widget.selected,
                      onChanged: (_) => widget.onToggle(),
                    ),
                  )
                : TypeBadge(r.type, key: const ValueKey('badge')),
          ),
          title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            recordSummary(r),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // The day header already gives the date, so the row shows the time.
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                TimeOfDay.fromDateTime(r.createdAt).format(context),
                style: context.text.labelMedium
                    ?.merge(tabular)
                    .copyWith(color: context.colors.onSurfaceVariant),
              ),
              if (r.favorite)
                Icon(
                  AppIcon.starFilled,
                  size: Space.x4 + Space.x1,
                  color: context.tokens.favorite,
                  semanticLabel: 'Favorite',
                ),
            ],
          ),
          onTap: widget.selecting ? widget.onToggle : open,
          onLongPress: () {
            Haptics.select();
            widget.onToggle();
          },
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x3,
        Space.gutter,
        Space.x2,
      ),
      child: Semantics(
        header: true,
        child: Text(label, style: context.text.titleSmall),
      ),
    ),
  );
}
