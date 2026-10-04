import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/application/recording_scheduler.dart';
import 'package:zerotv_player/features/recording/data/drift_recording_repository.dart';
import 'package:zerotv_player/features/recording/data/drift_scheduled_recording_repository.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

/// Provides the [RecordingRepository].
final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return DriftRecordingRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [ScheduledRecordingRepository].
final scheduledRecordingRepositoryProvider =
    Provider<ScheduledRecordingRepository>((ref) {
      return DriftScheduledRecordingRepository(ref.watch(appDatabaseProvider));
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

/// Provides the [RecordingScheduler]. Kept alive by `main.dart` reading
/// it once at startup; polling stops only when the container disposes.
final recordingSchedulerProvider = Provider<RecordingScheduler>((ref) {
  final scheduler = RecordingScheduler(
    schedules: ref.watch(scheduledRecordingRepositoryProvider),
    channels: ref.watch(channelRepositoryProvider),
    manage: ref.watch(manageRecordingProvider),
  );
  ref.onDispose(scheduler.stop);
  return scheduler;
});

/// All scheduled recordings, latest programme window first.
final scheduledRecordingsProvider = StreamProvider<List<ScheduledRecording>>((
  ref,
) {
  return ref.watch(scheduledRecordingRepositoryProvider).watchAll();
});
