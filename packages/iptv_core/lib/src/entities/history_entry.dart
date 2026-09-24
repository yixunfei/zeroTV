/// A single watch-history record: when a channel was played.
///
/// Keyed by channel identity key (tvgId when present, otherwise
/// normalized name), so history survives wholesale channel replacement
/// on sync.
class HistoryEntry {
  /// Creates the entry.
  const HistoryEntry({
    required this.channelKey,
    required this.channelName,
    required this.watchedAt,
  });

  /// Channel identity key.
  final String channelKey;

  /// Channel display name snapshot (the channel may disappear from the
  /// playlist later).
  final String channelName;

  /// When playback started.
  final DateTime watchedAt;
}
