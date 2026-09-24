import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/channel/data/drift_watch_history_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftWatchHistoryRepository repo;

  setUp(() {
    database = db.AppDatabase.memory();
    repo = DriftWatchHistoryRepository(database);
  });

  tearDown(() => database.close());

  HistoryEntry entry(String key, DateTime at, [String? name]) {
    return HistoryEntry(
      channelKey: key,
      channelName: name ?? key,
      watchedAt: at,
    );
  }

  test('watchRecent returns one entry per channel, latest first', () async {
    await repo.record(entry('a', DateTime(2026, 9, 22, 8)));
    await repo.record(entry('b', DateTime(2026, 9, 22, 9)));
    await repo.record(entry('a', DateTime(2026, 9, 22, 10), 'A 新名'));

    final recent = await repo.watchRecent().first;
    expect(recent, hasLength(2));
    expect(recent.first.channelKey, 'a');
    expect(recent.first.channelName, 'A 新名');
    expect(
      recent.first.watchedAt.isAtSameMomentAs(DateTime(2026, 9, 22, 10)),
      isTrue,
    );
    expect(recent.last.channelKey, 'b');
  });

  test('watchRecent respects the limit', () async {
    for (var i = 0; i < 5; i++) {
      await repo.record(entry('ch$i', DateTime(2026, 9, 22, 8 + i)));
    }
    final recent = await repo.watchRecent(limit: 2).first;
    expect(recent, hasLength(2));
    expect(recent.first.channelKey, 'ch4');
    expect(recent.last.channelKey, 'ch3');
  });
}
