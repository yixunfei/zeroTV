import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [WatchHistoryRepository].
class DriftWatchHistoryRepository implements WatchHistoryRepository {
  /// Creates the repository.
  DriftWatchHistoryRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<void> record(HistoryEntry entry) {
    // Keep one row per channel: watchRecent only ever surfaces the latest
    // entry per channelKey, so older duplicates are dead weight and the
    // table would otherwise grow without bounds.
    return _db.transaction(() async {
      await (_db.delete(
        _db.watchHistory,
      )..where((t) => t.channelKey.equals(entry.channelKey))).go();
      await _db
          .into(_db.watchHistory)
          .insert(
            db.WatchHistoryCompanion.insert(
              channelKey: entry.channelKey,
              channelName: entry.channelName,
              watchedAt: entry.watchedAt,
            ),
          );
    });
  }

  @override
  Future<void> remove(String channelKey) {
    return (_db.delete(
      _db.watchHistory,
    )..where((t) => t.channelKey.equals(channelKey))).go();
  }

  @override
  Future<void> clear() {
    return _db.delete(_db.watchHistory).go();
  }

  @override
  Stream<List<HistoryEntry>> watchRecent({int limit = 50}) {
    final latestAt = _db.watchHistory.watchedAt.max();
    final q = _db.selectOnly(_db.watchHistory)
      ..addColumns([
        _db.watchHistory.channelKey,
        _db.watchHistory.channelName,
        latestAt,
      ])
      ..groupBy([_db.watchHistory.channelKey])
      ..orderBy([OrderingTerm.desc(latestAt)])
      ..limit(limit);
    return q.watch().map((rows) {
      return [
        for (final r in rows)
          HistoryEntry(
            channelKey: r.read(_db.watchHistory.channelKey)!,
            channelName: r.read(_db.watchHistory.channelName)!,
            watchedAt: r.read(latestAt)!,
          ),
      ];
    });
  }
}
