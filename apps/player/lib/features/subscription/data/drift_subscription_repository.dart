import 'package:drift/drift.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [SubscriptionRepository].
class DriftSubscriptionRepository implements SubscriptionRepository {
  /// Creates the repository.
  DriftSubscriptionRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<List<Subscription>> watchAll() {
    final q = _db.select(_db.subscriptions)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<Subscription>> getAll() async {
    final q = _db.select(_db.subscriptions)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final rows = await q.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> upsert(Subscription subscription) {
    return _db
        .into(_db.subscriptions)
        .insertOnConflictUpdate(_toCompanion(subscription));
  }

  @override
  Future<void> remove(String id) {
    return (_db.delete(_db.subscriptions)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> markSynced(String id, DateTime syncedAt) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      db.SubscriptionsCompanion(lastSyncedAt: Value(syncedAt)),
    );
  }

  @override
  Future<void> rename(String id, String name) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      db.SubscriptionsCompanion(name: Value(name)),
    );
  }

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      db.SubscriptionsCompanion(enabled: Value(enabled)),
    );
  }

  Subscription _toDomain(db.Subscription row) {
    return Subscription(
      id: row.id,
      name: row.name,
      kind: SubscriptionKind.values.byName(row.kind),
      uri: row.uri,
      refreshInterval: Duration(seconds: row.refreshIntervalSeconds),
      enabled: row.enabled,
      lastSyncedAt: row.lastSyncedAt,
      channelGroupPrefix: row.channelGroupPrefix,
    );
  }

  db.SubscriptionsCompanion _toCompanion(Subscription s) {
    return db.SubscriptionsCompanion(
      id: Value(s.id),
      name: Value(s.name),
      kind: Value(s.kind.name),
      uri: Value(s.uri),
      refreshIntervalSeconds: Value(s.refreshInterval.inSeconds),
      enabled: Value(s.enabled),
      lastSyncedAt: Value(s.lastSyncedAt),
      channelGroupPrefix: Value(s.channelGroupPrefix),
    );
  }
}
