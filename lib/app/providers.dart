import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/db/scan_repository.dart';
import '../core/models.dart';
import '../core/parser/scan_parser.dart';

final repoProvider = ChangeNotifierProvider<ScanRepository>(
  (_) => throw UnimplementedError('overridden in main'),
);

/// "Now", overridable so goldens of time-based UI (greeting, week strip) are stable.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Index of the visible bottom tab; the scanner pauses its camera when it is not 0.
final currentTabProvider = StateProvider<int>((_) => 0);

final historyProvider = FutureProvider.autoDispose
    .family<List<ScanRecord>, (HistoryFilter, String)>(
      (ref, q) => ref.watch(repoProvider).list(filter: q.$1, search: q.$2),
    );

ScanRecord buildRecord(String raw, String format, ScanSource source) {
  final parsed = ScanParser.parse(raw, format);
  final now = DateTime.now();
  return ScanRecord(
    id: const Uuid().v4(),
    source: source,
    format: format,
    type: parsed.type,
    rawValue: raw,
    parsed: parsed.data,
    title: parsed.title,
    createdAt: now,
    updatedAt: now,
  );
}
