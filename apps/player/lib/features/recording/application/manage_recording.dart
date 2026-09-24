import 'dart:io';

import 'package:iptv_core/iptv_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

/// Result of starting a recording.
class StartRecordingResult {
  /// Creates the result.
  const StartRecordingResult(this.recording, this.handle);

  /// The persisted recording row.
  final Recording recording;

  /// The live capture handle.
  final RecordingHandle handle;
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
    await _repository.upsert(recording);
    final handle = await _recorder.start(
      url: Uri.parse(channel.streamUrl),
      filePath: filePath,
      headers: channel.httpHeaders,
    );
    return StartRecordingResult(recording, handle);
  }

  /// Stops [handle], persisting the final size and end time.
  Future<void> stop(Recording recording, RecordingHandle handle) async {
    await handle.stop();
    await _repository.finish(
      recording.id,
      DateTime.now(),
      handle.bytesWritten,
    );
  }

  /// Deletes [recording]'s row and its file (best-effort).
  Future<void> delete(Recording recording) async {
    await _repository.remove(recording.id);
    final file = File(recording.filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
