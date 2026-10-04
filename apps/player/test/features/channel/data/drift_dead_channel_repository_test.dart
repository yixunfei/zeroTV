import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/channel/data/drift_dead_channel_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftDeadChannelRepository repo;

  setUp(() {
    database = db.AppDatabase.memory();
    repo = DriftDeadChannelRepository(database);
  });

  tearDown(() => database.close());

  DeadChannel entry(String key, [String name = 'CCTV']) => DeadChannel(
    channelKey: key,
    channelName: '$name-$key',
    streamUrl: 'http://a/$key',
    markedAt: DateTime(2026, 9, 26, 8),
  );

  test('mark and watchKeys/watchAll', () async {
    await repo.mark(entry('a'));
    await repo.mark(entry('b'));

    expect(await repo.watchKeys().first, {'a', 'b'});
    final all = await repo.watchAll().first;
    expect(all, hasLength(2));
  });

  test('mark twice replaces instead of duplicating', () async {
    await repo.mark(entry('a'));
    await repo.mark(entry('a'));

    expect(await repo.watchKeys().first, {'a'});
    expect(await repo.watchAll().first, hasLength(1));
  });

  test('unmark removes the entry', () async {
    await repo.mark(entry('a'));
    await repo.mark(entry('b'));
    await repo.unmark('a');

    expect(await repo.watchKeys().first, {'b'});
  });

  test('clearOrphans removes marks whose channel no longer exists', () async {
    await repo.mark(entry('a'));
    await repo.mark(entry('b'));
    await repo.mark(entry('c'));

    await repo.clearOrphans({'b'});

    expect(await repo.watchKeys().first, {'b'});
  });

  test('clearOrphans with no existing channels clears all marks', () async {
    await repo.mark(entry('a'));
    await repo.mark(entry('b'));

    await repo.clearOrphans({});

    expect(await repo.watchKeys().first, isEmpty);
  });
}
