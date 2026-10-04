/// A channel the user marked as dead/unplayable.
///
/// Keyed by [channelKey] (tvgId when present, else normalized name) so
/// marks survive sync replacement — same contract as favorites/history.
class DeadChannel {
  /// Creates the record.
  const DeadChannel({
    required this.channelKey,
    required this.channelName,
    required this.streamUrl,
    required this.markedAt,
  });

  /// Channel identity key.
  final String channelKey;

  /// Channel display name snapshot, for the management page.
  final String channelName;

  /// Stream URL snapshot, for diagnostics.
  final String streamUrl;

  /// When the channel was marked dead.
  final DateTime markedAt;
}
