import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart'
    hide ScheduledRecording;
import 'package:zerotv_player/features/recording/data/drift_scheduled_recording_repository.dart';

void main() {
  late AppDatabase db;
  late DriftScheduledRecordingRepository repo;

  ScheduledRecording build({
    String id = 's1',
    DateTime? startAt,
    ScheduledRecordingState state = ScheduledRecordingState.pending,
  }) {
    final start = startAt ?? DateTime(2026, 10, 5, 19);
    return ScheduledRecording(
      id: id,
      channelKey: 'cctv1',
      channelName: 'CCTV-1',
      streamUrl: 'http://a/1',
      title: '新闻联播',
      startAt: start,
      endAt: start.add(const Duration(minutes: 30)),
      createdAt: DateTime(2026, 10, 4, 12),
      state: state,
    );
  }

  setUp(() {
    db = AppDatabase.memory();
    repo = DriftScheduledRecordingRepository(db);
  });

  tearDown(() => db.close());

  test('upsert then watchAll returns rows ordered by startAt desc', () async {
    await repo.upsert(build(id: 'old', startAt: DateTime(2026, 10, 4, 8)));
    await repo.upsert(build(id: 'new', startAt: DateTime(2026, 10, 5, 19)));

    final all = await repo.watchAll().first;
    expect(all.map((s) => s.id), ['new', 'old']);
    expect(all.first.channelName, 'CCTV-1');
    expect(all.first.state, ScheduledRecordingState.pending);
  });

  test('markState updates only the state column', () async {
    await repo.upsert(build());

    await repo.markState('s1', ScheduledRecordingState.recording);

    final all = await repo.watchAll().first;
    expect(all.single.state, ScheduledRecordingState.recording);
    expect(all.single.title, '新闻联播');
  });

  test('remove deletes the row without touching others', () async {
    await repo.upsert(build(id: 'a'));
    await repo.upsert(build(id: 'b', startAt: DateTime(2026, 10, 6, 20)));

    await repo.remove('a');

    final all = await repo.watchAll().first;
    expect(all.map((s) => s.id), ['b']);
  });
}
