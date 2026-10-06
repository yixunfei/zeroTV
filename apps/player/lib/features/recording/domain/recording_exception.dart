/// Machine-readable cause of a recording failure.
///
/// Presentation code maps these to localized user-facing strings; the
/// technical `RecordingException.message` must never be shown verbatim
/// in a non-Chinese locale.
enum RecordingErrorReason {
  /// The stream URL scheme is not HTTP(S).
  unsupportedScheme,

  /// HLS/DASH playlists cannot be captured byte-stream style.
  unsupportedPlaylist,

  /// The HTTP response status was not 2xx.
  httpStatus,

  /// The response content type is not a direct media stream.
  unsupportedContentType,
}

/// Failure to start a direct stream capture.
class RecordingException implements Exception {
  /// Creates the exception.
  const RecordingException(this.reason, this.message, {this.statusCode});

  /// Machine-readable cause for localized presentation.
  final RecordingErrorReason reason;

  /// Human-readable technical diagnostic (not localized).
  final String message;

  /// HTTP status code when [reason] is [RecordingErrorReason.httpStatus].
  final int? statusCode;

  @override
  String toString() => 'RecordingException: $message';
}
