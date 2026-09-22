/// Raw, unparsed playlist content fetched from somewhere.
class RawPlaylist {
  /// Creates raw playlist content.
  const RawPlaylist({required this.content, this.originUri});

  /// The playlist text (M3U or plain TXT).
  final String content;

  /// Where it came from, if applicable.
  final Uri? originUri;
}

/// Port for fetching playlist content from any origin
/// (remote URL, local file, pasted text, ...).
abstract interface class SubscriptionSource {
  /// Fetches the raw playlist content.
  Future<RawPlaylist> fetch();
}
