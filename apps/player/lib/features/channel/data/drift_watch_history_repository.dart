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
    return _db
        .into(_db.watchHistory)
        .insert(
          db.WatchHistoryCompanion.insert(
            channelKey: entry.channelKey,
            channelName: entry.channelName,
            watchedAt: entry.watchedAt,
          ),
        );
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
