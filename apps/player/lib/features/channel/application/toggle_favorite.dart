import 'package:iptv_core/iptv_core.dart';

/// Use case: flip the favorite state of a channel. Favorites are keyed
/// by [Channel.identityKey], so they survive wholesale channel
/// replacement on sync.
class ToggleFavorite {
  /// Creates the use case.
  ToggleFavorite({required FavoritesRepository favorites})
    : _favorites = favorites;

  final FavoritesRepository _favorites;

  /// Adds the channel to favorites when absent, removes it otherwise.
  Future<void> call(Channel channel) async {
    final key = channel.identityKey;
    if (await _favorites.isFavorite(key)) {
      await _favorites.remove(key);
    } else {
      await _favorites.add(key);
    }
  }
}
