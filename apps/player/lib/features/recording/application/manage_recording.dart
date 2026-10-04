import 'dart:io';

import 'package:iptv_core/iptv_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

/// Result of starting a recording.
class StartRecordingResult {
  /// Creates the result.
  const StartRecordingResult(this.recording, this.handle, this.done);

  /// The persisted recording row.
  final Recording recording;

  /// The live capture handle.
  final RecordingHandle handle;

  /// Completes after stream termination and database finalization.
  final Future<void> done;
}

/// Use case: start and stop manual recordings.
///
/// Each recording writes the raw stream bytes to a file under the app's
/// documents directory; no transcoding is performed.
class ManageRecording {
  /// Creates the use case.
  ManageRecording({
    required RecordingRepository repository,
    required StreamRecorder recorder,
    Future<Directory> Function()? documentsDir,
  }) : _repository = repository,
       _recorder = recorder,
       _documentsDir = documentsDir ?? getApplicationDocumentsDirectory;

  final RecordingRepository _repository;
  final StreamRecorder _recorder;
  final Future<Directory> Function() _documentsDir;
  final _completions = Expando<Future<void>>();
  final _active = <String, RecordingHandle>{};

  /// Starts recording [channel] to a new file and persists the row.
  Future<StartRecordingResult> start(Channel channel) async {
    final dir = await _documentsDir();
    final id = const Uuid().v4();
    final filePath = p.join(dir.path, 'recordings', '$id.ts');
    final startedAt = DateTime.now();
    final recording = Recording(
      id: id,
      channelKey: channel.identityKey,
      channelName: channel.name,
      filePath: filePath,
      startedAt: startedAt,
    );
    final handle = await _recorder.start(
      url: Uri.parse(channel.streamUrl),
      filePath: filePath,
      headers: channel.httpHeaders,
    );
    try {
      await _repository.upsert(recording);
    } on Object {
      // Best-effort cleanup: `handle.stop()` rethrows capture errors via
      // its `done` future, which must neither skip the file cleanup nor
      // replace the original database error.
      try {
        await handle.stop();
        final file = File(filePath);
        if (file.existsSync()) await file.delete();
      } on Object {
        // Cleanup failed (e.g. the file is still locked); the original
        // database error below is the one worth surfacing.
      }
      rethrow;
    }
    final done = _finalize(recording, handle);
    _completions[handle] = done;
    _active[recording.id] = handle;
    done.ignore();
    return StartRecordingResult(recording, handle, done);
  }

  Future<void> _finalize(Recording recording, RecordingHandle handle) async {
    try {
      await handle.done;
    } finally {
      if (identical(_active[recording.id], handle)) {
        _active.remove(recording.id);
      }
      final file = File(recording.filePath);
      final bytes = file.existsSync()
          ? await file.length()
          : handle.bytesWritten;
      await _repository.finish(recording.id, DateTime.now(), bytes);
    }
  }

  /// Stops [handle], persisting the final size and end time.
  ///
  /// A network error that aborted the capture is not rethrown: the bytes
  /// captured so far are still finalized and persisted, and the failure
  /// is already reported through the [StartRecordingResult.done] future.
  Future<void> stop(Recording recording, RecordingHandle handle) async {
    try {
      await handle.stop();
    } on Object {
      // The capture ended abnormally; finalization below still runs.
    }
    final done = _completions[handle] ?? _finalize(recording, handle);
    try {
      await done;
    } on Object {
      // Already surfaced via the recording's done future.
    }
  }

  /// Finalizes rows left "recording" by a crash or process kill, stamping
  /// them with the current time and the on-disk file size (0 when the
  /// file is gone). Intended to run once at startup; without it such rows
  /// would show "recording" forever with an ever-growing duration.
  Future<void> recoverOrphans() async {
    final recordings = await _repository.watchAll().first;
    for (final r in recordings) {
      if (r.endedAt != null) continue;
      final file = File(r.filePath);
      final bytes = file.existsSync() ? await file.length() : 0;
      await _repository.finish(r.id, DateTime.now(), bytes);
    }
  }

  /// Deletes [recording]'s row and its file (best-effort). An ongoing
  /// recording is stopped first so the file handle is released (on
  /// Windows, deleting an open file fails).
  Future<void> delete(Recording recording) async {
    final active = _active[recording.id];
    if (active != null) {
      await stop(recording, active);
    }
    await _repository.remove(recording.id);
    final file = File(recording.filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
