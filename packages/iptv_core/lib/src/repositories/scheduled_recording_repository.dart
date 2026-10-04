import 'package:iptv_core/src/entities/scheduled_recording.dart';

/// Persistence port for scheduled recordings.
abstract interface class ScheduledRecordingRepository {
  /// Watches all scheduled recordings, ordered by start time (latest
  /// first).
  Stream<List<ScheduledRecording>> watchAll();

  /// Inserts or updates [scheduled].
  Future<void> upsert(ScheduledRecording scheduled);

  /// Targeted single-field state transition for [id]; never touches the
  /// snapshot columns.
  Future<void> markState(String id, ScheduledRecordingState state);

  /// Removes the schedule with [id]. Does not touch any recording file
  /// already captured for it.
  Future<void> remove(String id);
}
