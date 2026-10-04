import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [ProbeResultRepository].
class DriftProbeResultRepository implements ProbeResultRepository {
  /// Creates the repository.
  DriftProbeResultRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<Map<String, ProbeResult>> watchAll() {
    return _db.select(_db.probeResults).watch().map((rows) {
      return {
        for (final r in rows) r.channelKey: _toDomain(r),
      };
    });
  }

  @override
  Future<void> save(String channelKey, ProbeResult result) {
    return _db
        .into(_db.probeResults)
        .insertOnConflictUpdate(
          db.ProbeResultsCompanion.insert(
            channelKey: channelKey,
            url: result.url,
            status: result.status.name,
            checkedAt: result.checkedAt,
            latencyMs: Value(result.latency?.inMilliseconds),
            httpStatus: Value(result.httpStatus),
            error: Value(result.error),
          ),
        );
  }

  @override
  Future<void> purgeStale(DateTime cutoff) {
    return (_db.delete(
      _db.probeResults,
    )..where((t) => t.checkedAt.isSmallerThanValue(cutoff))).go();
  }

  @override
  Future<void> clear() => _db.delete(_db.probeResults).go();

  ProbeResult _toDomain(db.ProbeResult row) {
    return ProbeResult(
      url: row.url,
      status: ProbeStatus.values.byName(row.status),
      checkedAt: row.checkedAt,
      latency: row.latencyMs == null
          ? null
          : Duration(milliseconds: row.latencyMs!),
      httpStatus: row.httpStatus,
      error: row.error,
    );
  }
}
