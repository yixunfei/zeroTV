/// A manual recording: raw stream bytes captured to a local file.
class Recording {
  /// Creates a recording.
  const Recording({
    required this.id,
    required this.channelKey,
    required this.channelName,
    required this.filePath,
    required this.startedAt,
    this.endedAt,
    this.sizeBytes = 0,
  });

  /// Stable unique id (uuid).
  final String id;

  /// Channel identity key.
  final String channelKey;

  /// Channel display name snapshot.
  final String channelName;

  /// Absolute path of the recorded file.
  final String filePath;

  /// When recording started.
  final DateTime startedAt;

  /// When recording stopped; null while still recording.
  final DateTime? endedAt;

  /// Size in bytes captured so far.
  final int sizeBytes;

  /// Whether the recording is still in progress.
  bool get isRecording => endedAt == null;

  /// Wall-clock duration of the recording so far. Clamped to zero so a
  /// system clock set back mid-recording never yields a negative value.
  Duration durationAt(DateTime now) {
    final duration = (endedAt ?? now).difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }
}
