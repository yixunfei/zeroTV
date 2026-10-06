/// Machine-readable cause of a subscription/EPG fetch failure.
///
/// Presentation code maps these to localized user-facing strings; the
/// [SubscriptionFetchException.message] is a technical diagnostic that
/// must never be shown verbatim in a non-Chinese locale.
enum SyncErrorReason {
  /// The playlist file does not exist on disk.
  fileMissing,

  /// Reading the local playlist file failed.
  fileReadFailed,

  /// The response body was empty.
  emptyBody,

  /// The response body is not an M3U playlist.
  notAPlaylist,

  /// No mirror candidate could be reached.
  allMirrorsUnreachable,

  /// The playlist contains no valid channels.
  noValidChannels,

  /// A pasted import contained no valid channels.
  pastedNoValidChannels,

  /// The EPG response body was empty.
  epgEmptyBody,

  /// Fetching the EPG feed over HTTP failed.
  epgFetchFailed,

  /// Parsing the EPG XMLTV document failed.
  epgParseFailed,
}

/// Failure to fetch or store a subscription's playlist.
class SubscriptionFetchException implements Exception {
  /// Creates the exception.
  const SubscriptionFetchException(this.reason, this.message);

  /// Machine-readable cause for localized presentation.
  final SyncErrorReason reason;

  /// Human-readable technical diagnostic (not localized).
  final String message;

  @override
  String toString() => 'SubscriptionFetchException: $message';
}
