import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [EpgRepository].
class DriftEpgRepository implements EpgRepository {
  /// Creates the repository.
  DriftEpgRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<List<EpgProgram>> programmesFor(
    String channelId,
    DateTime from,
    DateTime to,
  ) async {
    final q = _db.select(_db.epgProgrammes)
      ..where(
        (t) =>
            t.channelId.equals(channelId) &
            t.stop.isBiggerThanValue(from) &
            t.start.isSmallerThanValue(to),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.start)]);
    final rows = await q.get();
    return rows.map(_toProgram).toList();
  }

  @override
  Future<List<EpgProgram>> programmesInWindow(
    DateTime from,
    DateTime to,
  ) async {
    final q = _db.select(_db.epgProgrammes)
      ..where(
        (t) => t.stop.isBiggerThanValue(from) & t.start.isSmallerThanValue(to),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.start)]);
    final rows = await q.get();
    return rows.map(_toProgram).toList();
  }

  @override
  Future<List<EpgChannel>> allChannels() async {
    final rows = await _db.select(_db.epgChannels).get();
    return [
      for (final r in rows)
        EpgChannel(id: r.id, displayName: r.displayName, iconUrl: r.iconUrl),
    ];
  }

  @override
  Future<void> clear() {
    return _db.transaction(() async {
      await _db.delete(_db.epgProgrammes).go();
      await _db.delete(_db.epgChannels).go();
    });
  }

  @override
  Future<void> replaceFeed(EpgFeed feed) {
    return _db.transaction(() async {
      await _db.delete(_db.epgProgrammes).go();
      await _db.delete(_db.epgChannels).go();
      await _db.batch((b) {
        b
          ..insertAll(_db.epgChannels, [
            for (final c in feed.channels)
              db.EpgChannelsCompanion.insert(
                id: c.id,
                displayName: c.displayName,
                iconUrl: Value(c.iconUrl),
              ),
          ])
          ..insertAll(_db.epgProgrammes, [
            for (final p in feed.programmes)
              db.EpgProgrammesCompanion.insert(
                channelId: p.channelId,
                title: p.title,
                start: p.start,
                stop: p.stop,
                description: Value(p.description),
              ),
          ]);
      });
    });
  }

  EpgProgram _toProgram(db.EpgProgramme row) {
    return EpgProgram(
      channelId: row.channelId,
      title: row.title,
      start: row.start,
      stop: row.stop,
      description: row.description,
    );
  }
}
