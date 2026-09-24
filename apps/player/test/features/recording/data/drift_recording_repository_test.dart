import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/recording/data/drift_recording_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftRecordingRepository recordings;

  final started = DateTime.utc(2026, 9, 24, 12);
  final recording = Recording(
    id: 'r1',
    channelKey: 'cctv1',
    channelName: 'CCTV-1',
    filePath: '/tmp/r1.ts',
    startedAt: started,
  );

  setUp(() {
    database = db.AppDatabase.memory();
    recordings = DriftRecordingRepository(database);
  });

  tearDown(() => database.close());

  test('upsert then watchAll returns the recording', () async {
    await recordings.upsert(recording);
    final all = await recordings.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.channelName, 'CCTV-1');
    expect(all.single.isRecording, isTrue);
    expect(all.single.endedAt, isNull);
  });

  test('finish records the end time and size', () async {
    await recordings.upsert(recording);
    await recordings.finish('r1', DateTime.utc(2026, 9, 24, 13), 4096);

    final all = await recordings.watchAll().first;
    expect(all.single.isRecording, isFalse);
    expect(all.single.sizeBytes, 4096);
    expect(
      all.single.endedAt!.isAtSameMomentAs(DateTime.utc(2026, 9, 24, 13)),
      isTrue,
    );
  });

  test('watchAll orders newest first', () async {
    await recordings.upsert(recording);
    await recordings.upsert(
      Recording(
        id: 'r2',
        channelKey: 'hunan',
        channelName: '湖南卫视',
        filePath: '/tmp/r2.ts',
        startedAt: started.add(const Duration(hours: 1)),
      ),
    );

    final all = await recordings.watchAll().first;
    expect(all.map((r) => r.id).toList(), ['r2', 'r1']);
  });

  test('remove deletes the row', () async {
    await recordings.upsert(recording);
    await recordings.remove('r1');
    expect(await recordings.watchAll().first, isEmpty);
  });

  test('durationAt uses endedAt once finished', () {
    final finished = Recording(
      id: 'r1',
      channelKey: 'c',
      channelName: 'C',
      filePath: '/tmp/r.ts',
      startedAt: started,
      endedAt: started.add(const Duration(minutes: 30)),
    );
    expect(
      finished.durationAt(DateTime.utc(2026, 9, 24, 20)),
      const Duration(minutes: 30),
    );
  });
}
