import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [RecordingRepository].
class DriftRecordingRepository implements RecordingRepository {
  /// Creates the repository.
  DriftRecordingRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Recording>> watchAll() {
    final q = _db.select(_db.recordings)
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> upsert(Recording recording) {
    return _db
        .into(_db.recordings)
        .insertOnConflictUpdate(_toCompanion(recording));
  }

  @override
  Future<void> finish(String id, DateTime endedAt, int sizeBytes) async {
    await (_db.update(_db.recordings)..where((t) => t.id.equals(id))).write(
      db.RecordingsCompanion(
        endedAt: Value(endedAt),
        sizeBytes: Value(sizeBytes),
      ),
    );
  }

  @override
  Future<void> remove(String id) {
    return (_db.delete(_db.recordings)..where((t) => t.id.equals(id))).go();
  }

  Recording _toDomain(db.Recording row) {
    return Recording(
      id: row.id,
      channelKey: row.channelKey,
      channelName: row.channelName,
      filePath: row.filePath,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      sizeBytes: row.sizeBytes,
    );
  }

  db.RecordingsCompanion _toCompanion(Recording r) {
    return db.RecordingsCompanion(
      id: Value(r.id),
      channelKey: Value(r.channelKey),
      channelName: Value(r.channelName),
      filePath: Value(r.filePath),
      startedAt: Value(r.startedAt),
      endedAt: Value(r.endedAt),
      sizeBytes: Value(r.sizeBytes),
    );
  }
}
