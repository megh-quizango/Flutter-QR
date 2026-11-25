import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'settings.dart';

/// Lifetime collection: which content types the user has found, and how many codes in total.
/// Kept in prefs (not the history table) so clearing history or turning it off doesn't take it away.
class Progress {
  const Progress({this.found = const {}, this.total = 0});
  final Set<ContentType> found;
  final int total;

  static const foundKey = 'foundTypes', totalKey = 'totalCodes';

  factory Progress.load(SharedPreferences p) => Progress(
    found: {
      for (final n in p.getStringList(foundKey) ?? const <String>[])
        ...ContentType.values.where((t) => t.name == n),
    },
    total: p.getInt(totalKey) ?? 0,
  );
}

final progressProvider = NotifierProvider<ProgressNotifier, Progress>(
  ProgressNotifier.new,
);

class ProgressNotifier extends Notifier<Progress> {
  @override
  Progress build() => Progress.load(ref.watch(prefsProvider));

  Future<void> _store(Progress next) async {
    state = next;
    final p = ref.read(prefsProvider);
    await p.setStringList(Progress.foundKey, [
      for (final t in next.found) t.name,
    ]);
    await p.setInt(Progress.totalKey, next.total);
  }

  /// Counts a scanned or created code. Returns true when its type is new to the collection.
  Future<bool> log(ContentType type) async {
    final isNew = !state.found.contains(type);
    await _store(
      Progress(found: {...state.found, type}, total: state.total + 1),
    );
    return isNew;
  }

  /// First launch after this update: count what is already in history, without a celebration.
  Future<void> backfill(Set<ContentType> types, int count) async {
    if (ref.read(prefsProvider).containsKey(Progress.totalKey)) return;
    await _store(Progress(found: types, total: count));
  }
}
