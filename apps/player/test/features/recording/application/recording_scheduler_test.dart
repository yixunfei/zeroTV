import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/application/recording_scheduler.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_recording_repository.dart';
import '../../../helpers/fake_scheduled_recording_repository.dart';

void main() {
  late Directory tempDir;
  late FakeScheduledRecordingRepository schedules;
  late FakeRecordingRepository recordings;
  late _FakeRecorder recorder;
  late RecordingScheduler scheduler;

  const channel = Channel(name: 'CCTV-1', streamUrl: 'http://a/1');

  ScheduledRecording buildSchedule({
    required DateTime startAt,
    required DateTime endAt,
    String id = 's1',
    ScheduledRecordingState state = ScheduledRecordingState.pending,
  }) {
    return ScheduledRecording(
      id: id,
      channelKey: channel.identityKey,
      channelName: channel.name,
      streamUrl: channel.streamUrl,
      title: '新闻联播',
      startAt: startAt,
      endAt: endAt,
      createdAt: startAt.subtract(const Duration(days: 1)),
      state: state,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zerotv_sched_test');
    schedules = FakeScheduledRecordingRepository();
    recordings = FakeRecordingRepository();
    recorder = _FakeRecorder();
    scheduler = RecordingScheduler(
      schedules: schedules,
      channels: FakeChannelRepository(channels: const [channel]),
      manage: ManageRecording(
        repository: recordings,
        recorder: recorder,
        documentsDir: () async => tempDir,
      ),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('schedule persists a pending row and dedupes by programme', () async {
    final programme = EpgProgram(
      channelId: 'cctv1',
      title: '新闻联播',
      start: DateTime.now().add(const Duration(hours: 2)),
      stop: DateTime.now().add(const Duration(hours: 3)),
    );

    final first = await scheduler.schedule(channel, programme);
    final second = await scheduler.schedule(channel, programme);

    expect(first, isNotNull);
    expect(second, isNull);
    expect(schedules.length, 1);
    expect(schedules.byId(first!.id).state, ScheduledRecordingState.pending);
  });

  test('a due pending schedule fires and stops when the window ends', () async {
    final now = DateTime.now();
    await schedules.upsert(
      buildSchedule(
        startAt: now.subtract(const Duration(seconds: 1)),
        endAt: now.add(const Duration(milliseconds: 300)),
      ),
    );

    await scheduler.tickNow();
    expect(recorder.started, 1);
    expect(
      schedules.byId('s1').state,
      ScheduledRecordingState.recording,
    );

    await Future<void>.delayed(const Duration(milliseconds: 400));
    await scheduler.tickNow();

    expect(schedules.byId('s1').state, ScheduledRecordingState.done);
    expect(recordings.finishedId, isNotNull);
  });

  test('a window missed while the app was closed is marked failed', () async {
    final now = DateTime.now();
    await schedules.upsert(
      buildSchedule(
        startAt: now.subtract(const Duration(hours: 2)),
        endAt: now.subtract(const Duration(hours: 1)),
      ),
    );

    await scheduler.tickNow();

    expect(schedules.byId('s1').state, ScheduledRecordingState.failed);
    expect(recorder.started, 0);
  });

  test('a failing start marks the schedule failed', () async {
    recorder.fail = true;
    final now = DateTime.now();
    await schedules.upsert(
      buildSchedule(
        startAt: now.subtract(const Duration(seconds: 1)),
        endAt: now.add(const Duration(hours: 1)),
      ),
    );

    await scheduler.tickNow();

    expect(schedules.byId('s1').state, ScheduledRecordingState.failed);
  });

  test('cancel stops a running capture and marks the row cancelled', () async {
    final now = DateTime.now();
    await schedules.upsert(
      buildSchedule(
        startAt: now.subtract(const Duration(seconds: 1)),
        endAt: now.add(const Duration(hours: 1)),
      ),
    );
    await scheduler.tickNow();
    expect(recorder.started, 1);

    await scheduler.cancel(schedules.byId('s1'));

    expect(
      schedules.byId('s1').state,
      ScheduledRecordingState.cancelled,
    );
    expect(recordings.finishedId, isNotNull);
  });

  test(
    'a recording row orphaned by a crash resumes in an open window',
    () async {
      final now = DateTime.now();
      await schedules.upsert(
        buildSchedule(
          startAt: now.subtract(const Duration(minutes: 10)),
          endAt: now.add(const Duration(minutes: 30)),
          state: ScheduledRecordingState.recording,
        ),
      );

      await scheduler.tickNow();

      expect(recorder.started, 1);
      expect(
        schedules.byId('s1').state,
        ScheduledRecordingState.recording,
      );
    },
  );

  test('a stream ending naturally before the window marks done', () async {
    final now = DateTime.now();
    await schedules.upsert(
      buildSchedule(
        startAt: now.subtract(const Duration(seconds: 1)),
        endAt: now.add(const Duration(hours: 1)),
      ),
    );
    await scheduler.tickNow();

    recorder.completeActive();
    await Future<void>.delayed(Duration.zero);
    await scheduler.tickNow();

    expect(schedules.byId('s1').state, ScheduledRecordingState.done);
    expect(recordings.finishedId, isNotNull);
  });
}

class _FakeRecorder extends StreamRecorder {
  int started = 0;
  bool fail = false;
  _FakeHandle? active;

  /// Completes the active handle as if the stream had ended on its own.
  void completeActive() => active?.completeFromStream();

  @override
  Future<RecordingHandle> start({
    required Uri url,
    required String filePath,
    Map<String, String> headers = const {},
  }) async {
    if (fail) throw StateError('network failure');
    started++;
    return active = _FakeHandle();
  }
}

class _FakeHandle implements RecordingHandle {
  @override
  int bytesWritten = 0;

  bool _active = true;
  final _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  bool get isActive => _active;

  /// Simulates the remote closing the connection.
  void completeFromStream() {
    _active = false;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> stop() async => completeFromStream();
}
