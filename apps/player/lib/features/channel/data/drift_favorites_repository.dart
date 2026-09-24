import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;

/// Drift-backed [FavoritesRepository].
class DriftFavoritesRepository implements FavoritesRepository {
  /// Creates the repository.
  DriftFavoritesRepository(this._db);

  final db.AppDatabase _db;

  @override
  Stream<Set<String>> watchKeys() {
    return _db
        .select(_db.favorites)
        .watch()
        .map((rows) => rows.map((r) => r.channelKey).toSet());
  }

  @override
  Future<bool> isFavorite(String channelKey) async {
    final q = _db.select(_db.favorites)
      ..where((t) => t.channelKey.equals(channelKey));
    return await q.getSingleOrNull() != null;
  }

  @override
  Future<void> add(String channelKey) {
    return _db
        .into(_db.favorites)
        .insertOnConflictUpdate(
          db.FavoritesCompanion.insert(channelKey: channelKey),
        );
  }

  @override
  Future<void> remove(String channelKey) {
    return (_db.delete(
      _db.favorites,
    )..where((t) => t.channelKey.equals(channelKey))).go();
  }
}
