import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/recording/application/manage_recording.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

import '../../../helpers/fake_recording_repository.dart';

void main() {
  late Directory tempDir;
  late FakeRecordingRepository repository;
  late _FakeRecorder recorder;
  late ManageRecording manage;

  const channel = Channel(
    name: 'CCTV-1',
    streamUrl: 'http://a/1',
    tvgId: 'cctv1',
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zerotv_rec_test');
    repository = FakeRecordingRepository();
    recorder = _FakeRecorder();
    manage = ManageRecording(
      repository: repository,
      recorder: recorder,
      documentsDir: () async => tempDir,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('start persists a recording row and opens the capture', () async {
    final result = await manage.start(channel);

    expect(repository.saved, isNotNull);
    expect(repository.saved!.channelName, 'CCTV-1');
    expect(result.recording.channelKey, 'cctv1');
    expect(result.recording.filePath, contains('recordings'));
    expect(result.recording.filePath, endsWith('.ts'));
    expect(recorder.started, 1);
    expect(result.handle.isActive, isTrue);
  });

  test('stop finalizes size and end time', () async {
    final result = await manage.start(channel);
    result.handle.bytesWritten = 2048;

    await manage.stop(result.recording, result.handle);

    expect(repository.finishedId, result.recording.id);
    expect(repository.finishedSize, 2048);
    expect(result.handle.isActive, isFalse);
  });

  test('failed start does not create a phantom recording', () async {
    recorder.fail = true;
    await expectLater(manage.start(channel), throwsStateError);
    expect(repository.saved, isNull);
  });

  test('natural completion finalizes the row without a stop action', () async {
    final result = await manage.start(channel);
    result.handle.bytesWritten = 42;
    await result.handle.stop();
    await result.done;
    expect(repository.finishedId, result.recording.id);
    expect(repository.finishedSize, 42);
  });

  test('recoverOrphans finalizes rows left recording by a crash', () async {
    final orphanFile = File('${tempDir.path}/orphan.ts');
    await orphanFile.writeAsBytes(List.filled(100, 1));
    final orphan = Recording(
      id: 'orphan',
      channelKey: 'cctv1',
      channelName: 'CCTV-1',
      filePath: orphanFile.path,
      startedAt: DateTime(2026, 9, 20),
    );
    final finished = Recording(
      id: 'done',
      channelKey: 'cctv2',
      channelName: 'CCTV-2',
      filePath: '${tempDir.path}/done.ts',
      startedAt: DateTime(2026, 9, 20),
      endedAt: DateTime(2026, 9, 20, 1),
      sizeBytes: 5,
    );
    repository = FakeRecordingRepository([orphan, finished]);
    manage = ManageRecording(
      repository: repository,
      recorder: recorder,
      documentsDir: () async => tempDir,
    );

    await manage.recoverOrphans();

    final rows = await repository.watchAll().first;
    final recovered = rows.firstWhere((r) => r.id == 'orphan');
    expect(recovered.endedAt, isNotNull);
    expect(recovered.sizeBytes, 100);
    // Already finished rows are untouched.
    final untouched = rows.firstWhere((r) => r.id == 'done');
    expect(untouched.sizeBytes, 5);
  });

  test('delete removes the row and the file', () async {
    final result = await manage.start(channel);
    final file = File(result.recording.filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);

    await manage.delete(result.recording);

    expect(repository.removedId, result.recording.id);
    expect(file.existsSync(), isFalse);
  });
}

class _FakeRecorder extends StreamRecorder {
  int started = 0;
  bool fail = false;

  @override
  Future<RecordingHandle> start({
    required Uri url,
    required String filePath,
    Map<String, String> headers = const {},
  }) async {
    if (fail) throw StateError('network failure');
    started++;
    return _FakeHandle();
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

  @override
  Future<void> stop() async {
    _active = false;
    if (!_done.isCompleted) _done.complete();
  }
}
