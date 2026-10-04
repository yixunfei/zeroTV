import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [ScheduledRecordingRepository].
class DriftScheduledRecordingRepository
    implements ScheduledRecordingRepository {
  /// Creates the repository.
  DriftScheduledRecordingRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<ScheduledRecording>> watchAll() {
    final q = _db.select(_db.scheduledRecordings)
      ..orderBy([(t) => OrderingTerm.desc(t.startAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<void> upsert(ScheduledRecording scheduled) {
    return _db
        .into(_db.scheduledRecordings)
        .insertOnConflictUpdate(_toCompanion(scheduled));
  }

  @override
  Future<void> markState(String id, ScheduledRecordingState state) {
    return (_db.update(_db.scheduledRecordings)..where((t) => t.id.equals(id)))
        .write(db.ScheduledRecordingsCompanion(state: Value(state.name)));
  }

  @override
  Future<void> remove(String id) {
    return (_db.delete(
      _db.scheduledRecordings,
    )..where((t) => t.id.equals(id))).go();
  }

  ScheduledRecording _toDomain(db.ScheduledRecording row) {
    return ScheduledRecording(
      id: row.id,
      channelKey: row.channelKey,
      channelName: row.channelName,
      streamUrl: row.streamUrl,
      title: row.title,
      startAt: row.startAt,
      endAt: row.endAt,
      createdAt: row.createdAt,
      state: ScheduledRecordingState.values.byName(row.state),
    );
  }

  db.ScheduledRecordingsCompanion _toCompanion(ScheduledRecording s) {
    return db.ScheduledRecordingsCompanion(
      id: Value(s.id),
      channelKey: Value(s.channelKey),
      channelName: Value(s.channelName),
      streamUrl: Value(s.streamUrl),
      title: Value(s.title),
      startAt: Value(s.startAt),
      endAt: Value(s.endAt),
      createdAt: Value(s.createdAt),
      state: Value(s.state.name),
    );
  }
}
