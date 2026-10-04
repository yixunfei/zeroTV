/// Lifecycle of a scheduled (EPG-based) recording.
enum ScheduledRecordingState {
  /// Waiting for the programme window to open.
  pending,

  /// Capture is running right now.
  recording,

  /// The programme window was captured (fully or the remainder of it).
  done,

  /// The start failed (stream unreachable, unsupported protocol) or the
  /// window was missed entirely while the app was not running.
  failed,

  /// The user cancelled before the window ended.
  cancelled,
}

/// A recording scheduled for a future programme window, typically picked
/// from the EPG guide. Snapshots the channel coordinates so it stays
/// meaningful even after a playlist sync replaces the channel row.
class ScheduledRecording {
  /// Creates a scheduled recording.
  const ScheduledRecording({
    required this.id,
    required this.channelKey,
    required this.channelName,
    required this.streamUrl,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    this.state = ScheduledRecordingState.pending,
  });

  /// Stable unique id (uuid).
  final String id;

  /// Channel identity key (see `Channel.identityKey`).
  final String channelKey;

  /// Channel display name snapshot.
  final String channelName;

  /// Stream URL snapshot, used as a fallback when the channel has since
  /// disappeared from every subscription.
  final String streamUrl;

  /// Programme title snapshot.
  final String title;

  /// Programme start time; capture fires once the clock reaches it.
  final DateTime startAt;

  /// Programme end time; capture stops once the clock reaches it.
  final DateTime endAt;

  /// When the schedule was created.
  final DateTime createdAt;

  /// Current lifecycle state.
  final ScheduledRecordingState state;

  /// Whether the schedule is still waiting for its window.
  bool get isPending => state == ScheduledRecordingState.pending;

  /// Whether a capture is running for this schedule.
  bool get isRecording => state == ScheduledRecordingState.recording;

  /// Whether the schedule still expects work (pending or recording).
  bool get isActive => isPending || isRecording;

  /// Copies the schedule with a new [state].
  ScheduledRecording withState(ScheduledRecordingState state) {
    return ScheduledRecording(
      id: id,
      channelKey: channelKey,
      channelName: channelName,
      streamUrl: streamUrl,
      title: title,
      startAt: startAt,
      endAt: endAt,
      createdAt: createdAt,
      state: state,
    );
  }
}
