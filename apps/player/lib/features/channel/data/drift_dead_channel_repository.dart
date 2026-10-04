import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [DeadChannelRepository].
class DriftDeadChannelRepository implements DeadChannelRepository {
  /// Creates the repository.
  DriftDeadChannelRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<Set<String>> watchKeys() {
    return _db.select(_db.deadChannels).watch().map((rows) {
      return {for (final r in rows) r.channelKey};
    });
  }

  @override
  Stream<List<DeadChannel>> watchAll() {
    final q = _db.select(_db.deadChannels)
      ..orderBy([(t) => OrderingTerm.desc(t.markedAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> mark(DeadChannel entry) {
    return _db
        .into(_db.deadChannels)
        .insertOnConflictUpdate(
          db.DeadChannelsCompanion.insert(
            channelKey: entry.channelKey,
            channelName: entry.channelName,
            streamUrl: entry.streamUrl,
            markedAt: Value(entry.markedAt),
          ),
        );
  }

  @override
  Future<void> unmark(String channelKey) {
    return (_db.delete(
      _db.deadChannels,
    )..where((t) => t.channelKey.equals(channelKey))).go();
  }

  @override
  Future<void> clearOrphans(Set<String> existingKeys) {
    return (_db.delete(
      _db.deadChannels,
    )..where((t) => t.channelKey.isNotIn(existingKeys))).go();
  }

  DeadChannel _toDomain(db.DeadChannel row) {
    return DeadChannel(
      channelKey: row.channelKey,
      channelName: row.channelName,
      streamUrl: row.streamUrl,
      markedAt: row.markedAt,
    );
  }
}
