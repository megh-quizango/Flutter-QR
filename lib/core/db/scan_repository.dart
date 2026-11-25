import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

enum HistoryFilter { all, scanned, created, favorites }

/// Local history store. Notifies listeners on every change so lists reload.
class ScanRepository extends ChangeNotifier {
  ScanRepository(this._db);

  static const cap = 5000;
  final Database _db;

  static Future<ScanRepository> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'scanlight.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          '''
          CREATE TABLE scans(
            id TEXT PRIMARY KEY, source TEXT NOT NULL, format TEXT NOT NULL, type TEXT NOT NULL,
            raw_value TEXT NOT NULL, parsed TEXT NOT NULL, title TEXT NOT NULL,
            favorite INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''',
        );
        await db.execute(
          'CREATE INDEX idx_scans_created ON scans(created_at DESC)',
        );
        await db.execute('CREATE INDEX idx_scans_favorite ON scans(favorite)');
      },
      // Migration hook (NFR-6): add `if (old < 2) ...` steps here for future schema versions.
      onUpgrade: (db, oldVersion, newVersion) async {},
    );
    return ScanRepository(db);
  }

  Future<void> save(ScanRecord r) async {
    await _db.insert(
      'scans',
      r.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // R-HIS-8: over the cap, drop the oldest non-favorites.
    await _db.rawDelete('''
      DELETE FROM scans WHERE favorite = 0 AND id IN (
        SELECT id FROM scans WHERE favorite = 0 ORDER BY created_at ASC
        LIMIT max(0, (SELECT count(*) FROM scans) - $cap))''');
    notifyListeners();
  }

  Future<ScanRecord?> get(String id) async {
    final rows = await _db.query('scans', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : ScanRecord.fromRow(rows.first);
  }

  Future<List<ScanRecord>> list({
    HistoryFilter filter = HistoryFilter.all,
    String search = '',
  }) async {
    final where = <String>[];
    final args = <Object>[];
    switch (filter) {
      case HistoryFilter.scanned:
        where.add("source != 'created'");
      case HistoryFilter.created:
        where.add("source = 'created'");
      case HistoryFilter.favorites:
        where.add('favorite = 1');
      case HistoryFilter.all:
    }
    if (search.trim().isNotEmpty) {
      where.add('(title LIKE ? OR raw_value LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q]);
    }
    final rows = await _db.query(
      'scans',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map(ScanRecord.fromRow).toList();
  }

  /// Distinct types and total rows, used once to seed the collection.
  Future<(Set<ContentType>, int)> summary() async {
    final rows = await _db.rawQuery(
      'SELECT type, count(*) AS n FROM scans GROUP BY type',
    );
    return (
      {
        for (final r in rows)
          ...ContentType.values.where((t) => t.name == r['type']),
      },
      rows.fold<int>(0, (sum, r) => sum + (r['n']! as int)),
    );
  }

  Future<void> setFavorite(String id, bool favorite) async {
    await _db.update(
      'scans',
      {
        'favorite': favorite ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<void> delete(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await _db.delete(
      'scans',
      where: 'id IN (${List.filled(list.length, '?').join(',')})',
      whereArgs: list,
    );
    notifyListeners();
  }

  Future<void> clear() async {
    await _db.delete('scans');
    notifyListeners();
  }
}
