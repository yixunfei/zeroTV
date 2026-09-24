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

  @override
  Future<RecordingHandle> start({
    required Uri url,
    required String filePath,
    Map<String, String> headers = const {},
  }) async {
    started++;
    return _FakeHandle();
  }
}

class _FakeHandle implements RecordingHandle {
  @override
  int bytesWritten = 0;

  bool _active = true;

  @override
  Future<void> get done => Future<void>.value();

  @override
  bool get isActive => _active;

  @override
  Future<void> stop() async {
    _active = false;
  }
}
