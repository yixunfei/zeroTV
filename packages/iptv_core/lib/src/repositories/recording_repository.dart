import 'package:iptv_core/iptv_core.dart';

/// Persistence port for recordings.
abstract interface class RecordingRepository {
  /// Watches all recordings, newest first.
  Stream<List<Recording>> watchAll();

  /// Inserts or updates [recording].
  Future<void> upsert(Recording recording);

  /// Records the final size and end time for [id].
  Future<void> finish(String id, DateTime endedAt, int sizeBytes);

  /// Removes the recording with [id] (the file itself is deleted by the
  /// caller, which owns the filesystem).
  Future<void> remove(String id);
}
