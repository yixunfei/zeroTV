import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/data/drift_recording_repository.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

/// Provides the [RecordingRepository].
final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return DriftRecordingRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [StreamRecorder] (released on dispose).
final streamRecorderProvider = Provider<StreamRecorder>((ref) {
  final recorder = StreamRecorder();
  ref.onDispose(recorder.close);
  return recorder;
});

/// Provides the [ManageRecording] use case.
final manageRecordingProvider = Provider<ManageRecording>((ref) {
  return ManageRecording(
    repository: ref.watch(recordingRepositoryProvider),
    recorder: ref.watch(streamRecorderProvider),
  );
});

/// All recordings, newest first.
final recordingsProvider = StreamProvider<List<Recording>>((ref) {
  return ref.watch(recordingRepositoryProvider).watchAll();
});
