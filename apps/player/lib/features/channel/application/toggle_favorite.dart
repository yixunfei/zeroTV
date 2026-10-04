import 'package:iptv_core/iptv_core.dart';

/// Use case: flip the favorite state of a channel. Favorites are keyed
/// by [Channel.identityKey], so they survive wholesale channel
/// replacement on sync.
class ToggleFavorite {
  /// Creates the use case.
  ToggleFavorite({required FavoritesRepository favorites})
    : _favorites = favorites;

  final FavoritesRepository _favorites;

  /// In-flight toggles keyed by channel, so rapid double-taps can't
  /// interleave two read-modify-write cycles (which would both read the
  /// same state and cancel each other out).
  final Map<String, Future<void>> _pending = {};

  /// Adds the channel to favorites when absent, removes it otherwise.
  Future<void> call(Channel channel) {
    final key = channel.identityKey;
    return _pending[key] ??= _toggle(key);
  }

  Future<void> _toggle(String key) async {
    try {
      if (await _favorites.isFavorite(key)) {
        await _favorites.remove(key);
      } else {
        await _favorites.add(key);
      }
    } finally {
      // `removeWhere` (void) rather than `remove` — the latter returns
      // the in-flight future, which would read as discarded here.
      _pending.removeWhere((k, _) => k == key);
    }
  }
}
