/// Persistence port for favorite channels.
///
/// Favorites are keyed by channel identity key (tvgId when present,
/// otherwise normalized name) so they survive wholesale channel
/// replacement on sync.
abstract interface class FavoritesRepository {
  /// Watches the set of favorite channel keys.
  Stream<Set<String>> watchKeys();

  /// Returns whether [channelKey] is a favorite.
  Future<bool> isFavorite(String channelKey);

  /// Marks [channelKey] as favorite; adding twice is a no-op.
  Future<void> add(String channelKey);

  /// Removes [channelKey] from favorites.
  Future<void> remove(String channelKey);
}
