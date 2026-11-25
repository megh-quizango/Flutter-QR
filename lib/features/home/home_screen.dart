import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/db/scan_repository.dart';
import '../../core/models.dart';
import '../../core/parser/payload_encoder.dart';
import '../../core/progress.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../ui/app_icons.dart';
import '../../ui/responsive.dart';
import '../../ui/widgets.dart';
import '../create/create_sheet.dart';
import '../result/result_screen.dart';

/// Codes per day for the 7 days ending [now] (index 6 = today).
List<int> weekCounts(List<ScanRecord> records, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final counts = List.filled(7, 0);
  for (final r in records) {
    final c = r.createdAt;
    final ago = today.difference(DateTime(c.year, c.month, c.day)).inDays;
    if (ago >= 0 && ago < 7) counts[6 - ago]++;
  }
  return counts;
}

String codes(int n) => '$n ${n == 1 ? 'code' : 'codes'}';

/// Home: the scan panel, your numbers, the last 7 days, your collection, recent codes and
/// quick create. Chrome is neutral; the collection is the one place with colour.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final progress = ref.watch(progressProvider);
    final records =
        ref.watch(historyProvider((HistoryFilter.all, ''))).valueOrNull ??
        const <ScanRecord>[];
    final week = weekCounts(records, now);
    final weekTotal = week.fold<int>(0, (a, b) => a + b);
    final l = MaterialLocalizations.of(context);
    final step = context.motion.revealStagger;
    var i = 0;
    // One entrance: the first six blocks fade and rise in order, the rest are just there.
    Widget reveal(Widget child) =>
        Reveal(index: i, step: step, skip: i++ >= 6, child: child);

    final header = <Widget>[
      reveal(
        Row(
          children: [
            Brackets(
              color: context.colors.primary,
              arm: Space.x1 + 1,
              stroke: 1.5,
              child: const SizedBox.square(dimension: Space.x4),
            ),
            const SizedBox(width: Space.x2),
            Text(
              'ScanLight',
              style: context.text.titleSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.x2),
      reveal(
        Semantics(
          header: true,
          child: Text(
            l.formatMediumDate(now),
            style: context.text.headlineSmall,
          ),
        ),
      ),
    ];
    final left = <Widget>[
      reveal(_ScanPanel(onTap: () => goTab(context, ref, 1))),
      const SizedBox(height: Space.x3),
      reveal(
        _Stats([
          ('${progress.total}', 'All time'),
          ('$weekTotal', 'Last 7 days'),
          (
            '${progress.found.length} of ${ContentType.values.length}',
            'Types found',
          ),
        ]),
      ),
      const SizedBox(height: Space.x3),
      reveal(_WeekCard(counts: week, total: weekTotal, now: now)),
    ];
    final right = <Widget>[
      reveal(_CollectionCard(found: progress.found)),
      _Heading(
        'Recent',
        action: records.isEmpty
            ? null
            : TextButton(
                onPressed: () => goTab(context, ref, 3),
                child: const Text('See all'),
              ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: records.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Space.x4),
                child: Text(
                  'Codes you scan or create show up here',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                children: [
                  for (final (n, r) in records.take(3).indexed) ...[
                    if (n > 0)
                      Divider(
                        height: 1,
                        indent: Space.gutter + Space.tap + Space.x4,
                        color: context.colors.onSurface.withValues(
                          alpha: Opacities.hairline,
                        ),
                      ),
                    ListTile(
                      leading: TypeBadge(r.type, size: Space.x10),
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        recordSummary(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(AppIcon.chevron),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ResultScreen(record: r),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      const _Heading('Make a code'),
      Wrap(
        spacing: Space.x2,
        runSpacing: Space.x2,
        children: [
          for (final t in PayloadEncoder.createTypes)
            ActionChip(
              avatar: Icon(typeIcon(t)),
              label: Text(typeLabel(t)),
              backgroundColor: context.colors.surfaceContainerLowest,
              side: BorderSide(
                color: context.colors.onSurface.withValues(
                  alpha: Opacities.hairline,
                ),
              ),
              onPressed: () {
                Haptics.select();
                showCreateSheet(context, t);
              },
            ),
        ],
      ),
    ];
    // Expanded windows: actions and numbers on the left, collection and history on the right.
    final wide = context.windowSize == WindowSize.expanded;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: MaxWidth(
          ContentWidth.wide,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x4,
              Space.gutter,
              Space.x8,
            ),
            children: [
              ...header,
              const SizedBox(height: Space.x6),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: left,
                      ),
                    ),
                    const SizedBox(width: Space.x6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: right,
                      ),
                    ),
                  ],
                )
              else ...[
                ...left,
                const SizedBox(height: Space.x3),
                ...right,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.x8, bottom: Space.x2),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: context.text.titleMedium),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// The main action, styled like the scanner itself: an ink panel with green viewfinder brackets.
class _ScanPanel extends StatelessWidget {
  const _ScanPanel({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.theme.brightness == Brightness.dark;
    return PressScale(
      child: Material(
        color: dark ? Palette.grey800 : Palette.grey875,
        clipBehavior: Clip.antiAlias,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(
            color: t.onCamera.withValues(alpha: Opacities.hairline),
          ),
        ),
        child: InkWell(
          onTap: () {
            Haptics.select();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(Space.x6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan a code',
                        style: context.text.titleLarge?.copyWith(
                          color: t.onCamera,
                        ),
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        'QR codes and barcodes, from the camera or a photo',
                        style: context.text.bodyMedium?.copyWith(
                          color: t.onCameraMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x4),
                Brackets(
                  color: t.signal,
                  child: SizedBox.square(
                    dimension: Space.control + Space.x4,
                    child: Icon(AppIcon.qr, color: t.onCamera, size: Space.x8),
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

/// Three figures in one card, split by hairlines.
class _Stats extends StatelessWidget {
  const _Stats(this.items);
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (n, (value, label)) in items.indexed) ...[
              if (n > 0)
                VerticalDivider(
                  width: 1,
                  color: context.colors.onSurface.withValues(
                    alpha: Opacities.hairline,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: context.text.titleLarge?.merge(tabular),
                        ),
                      ),
                      Text(
                        label,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Seven bars, one per day. Today carries the accent, other days are neutral steps.
class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.counts,
    required this.total,
    required this.now,
  });
  final List<int> counts;
  final int total;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final c = context.colors;
    final most = counts.reduce((a, b) => a > b ? a : b);
    const barMax = Space.x12 + Space.x4;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Last 7 days', style: context.text.titleSmall),
                ),
                Text(
                  codes(total),
                  style: context.text.bodySmall
                      ?.merge(tabular)
                      .copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Semantics(
              label: 'Codes per day, last 7 days: ${counts.join(', ')}',
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var d = 0; d < 7; d++)
                      Expanded(
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: most == 0 ? 0 : counts[d] / most,
                              ),
                              duration: context.motion.slow,
                              curve: context.motion.slowCurve,
                              builder: (context, f, _) => Container(
                                width: Space.x5,
                                height: Space.x1 + (barMax - Space.x1) * f,
                                decoration: BoxDecoration(
                                  color: d == 6
                                      ? c.primary
                                      : c.onSurface.withValues(
                                          alpha: counts[d] > 0 ? 0.18 : 0.06,
                                        ),
                                  borderRadius: BorderRadius.circular(Space.x1),
                                ),
                              ),
                            ),
                            const SizedBox(height: Space.x2),
                            Text(
                              l.narrowWeekdays[now
                                      .subtract(Duration(days: 6 - d))
                                      .weekday %
                                  7],
                              style: context.text.bodySmall?.copyWith(
                                color: d == 6
                                    ? c.onSurface
                                    : c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one colourful moment: every content type as a badge, in its colour once found.
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.found});
  final Set<ContentType> found;

  @override
  Widget build(BuildContext context) {
    const all = ContentType.values;
    final c = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Collection', style: context.text.titleSmall),
                ),
                Text(
                  '${found.length} of ${all.length} types',
                  style: context.text.bodySmall
                      ?.merge(tabular)
                      .copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: found.length / all.length),
              duration: context.motion.slow,
              curve: context.motion.slowCurve,
              builder: (context, f, _) => LinearProgressIndicator(
                value: f,
                minHeight: Space.x1,
                color: c.primary,
                backgroundColor: c.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(Space.x1 / 2),
              ),
            ),
            const SizedBox(height: Space.x4),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x3,
              children: [
                for (final t in all)
                  found.contains(t)
                      ? Tooltip(
                          message: '${typeLabel(t)}: collected',
                          triggerMode: TooltipTriggerMode.tap,
                          child: TypeBadge(t, solid: true),
                        )
                      : Tooltip(
                          message:
                              'Scan or create a ${typeLabel(t)} code to collect it',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Semantics(
                            label: '${typeLabel(t)}, not collected yet',
                            child: ExcludeSemantics(
                              child: Container(
                                width: Space.tap,
                                height: Space.tap,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.onSurface.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Icon(
                                  typeIcon(t),
                                  size: Space.x5,
                                  color: c.outline,
                                ),
                              ),
                            ),
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
