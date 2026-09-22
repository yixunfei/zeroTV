import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [ChannelRepository].
class DriftChannelRepository implements ChannelRepository {
  /// Creates the repository.
  DriftChannelRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Channel>> watchBySubscription(String subscriptionId) {
    final q = _db.select(_db.channels)
      ..where((t) => t.subscriptionId.equals(subscriptionId))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<Channel>> watchAll() {
    final q = _db.select(_db.channels)
      ..orderBy([
        (t) => OrderingTerm.asc(t.subscriptionId),
        (t) => OrderingTerm.asc(t.position),
      ]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<String>> watchGroups(String subscriptionId) {
    return _groupsWhere(subscriptionId: subscriptionId);
  }

  @override
  Stream<List<String>> watchAllGroups() {
    return _groupsWhere();
  }

  @override
  Future<void> replaceAll(
    String subscriptionId,
    List<Channel> channels,
  ) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.channels,
      )..where((t) => t.subscriptionId.equals(subscriptionId))).go();
      await _db.batch((b) {
        b.insertAll(_db.channels, [
          for (var i = 0; i < channels.length; i++)
            _toCompanion(subscriptionId, channels[i], i),
        ]);
      });
    });
  }

  Stream<List<String>> _groupsWhere({String? subscriptionId}) {
    final q = _db.selectOnly(_db.channels, distinct: true)
      ..addColumns([_db.channels.groupTitle]);
    if (subscriptionId != null) {
      q.where(_db.channels.subscriptionId.equals(subscriptionId));
    }
    q.orderBy([OrderingTerm.asc(_db.channels.groupTitle)]);
    return q.watch().map((rows) {
      return [
        for (final r in rows)
          r.read(_db.channels.groupTitle) ?? ungroupedGroupLabel,
      ];
    });
  }

  Channel _toDomain(db.Channel row) {
    return Channel(
      name: row.name,
      streamUrl: row.streamUrl,
      tvgId: row.tvgId,
      logoUrl: row.logoUrl,
      groupTitle: row.groupTitle,
      catchupSource: row.catchupSource,
      catchupDays: row.catchupDays,
      userAgent: row.userAgent,
      referrer: row.referrer,
    );
  }

  db.ChannelsCompanion _toCompanion(
    String subscriptionId,
    Channel c,
    int position,
  ) {
    return db.ChannelsCompanion(
      subscriptionId: Value(subscriptionId),
      name: Value(c.name),
      streamUrl: Value(c.streamUrl),
      tvgId: Value(c.tvgId),
      logoUrl: Value(c.logoUrl),
      groupTitle: Value(c.groupTitle),
      catchupSource: Value(c.catchupSource),
      catchupDays: Value(c.catchupDays),
      userAgent: Value(c.userAgent),
      referrer: Value(c.referrer),
      position: Value(position),
    );
  }
}
