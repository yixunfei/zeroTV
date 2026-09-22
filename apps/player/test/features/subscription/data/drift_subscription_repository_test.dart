import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/subscription/data/drift_subscription_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftSubscriptionRepository repo;

  setUp(() {
    database = db.AppDatabase.memory();
    repo = DriftSubscriptionRepository(database);
  });

  tearDown(() => database.close());

  const sample = Subscription(
    id: 's1',
    name: '测试源',
    kind: SubscriptionKind.remoteUrl,
    uri: 'https://example.com/a.m3u8',
  );

  test('upsert then getAll returns the subscription', () async {
    await repo.upsert(sample);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.name, '测试源');
    expect(all.single.kind, SubscriptionKind.remoteUrl);
    expect(all.single.uri, 'https://example.com/a.m3u8');
    expect(all.single.refreshInterval, const Duration(hours: 6));
    expect(all.single.enabled, isTrue);
    expect(all.single.lastSyncedAt, isNull);
  });

  test('upsert twice updates instead of duplicating', () async {
    await repo.upsert(sample);
    await repo.upsert(
      const Subscription(
        id: 's1',
        name: '改名',
        kind: SubscriptionKind.remoteUrl,
        uri: 'https://example.com/a.m3u8',
        enabled: false,
      ),
    );
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.name, '改名');
    expect(all.single.enabled, isFalse);
  });

  test('markSynced sets lastSyncedAt', () async {
    await repo.upsert(sample);
    final t = DateTime(2026, 9, 22, 8);
    await repo.markSynced('s1', t);
    final restored = (await repo.getAll()).single.lastSyncedAt;
    expect(restored, isNotNull);
    expect(restored!.isAtSameMomentAs(t), isTrue);
  });

  test('rename updates only the name', () async {
    await repo.upsert(sample);
    final t = DateTime(2026, 9, 22, 8);
    await repo.markSynced('s1', t);
    await repo.rename('s1', '新名字');
    final stored = (await repo.getAll()).single;
    expect(stored.name, '新名字');
    expect(stored.enabled, isTrue);
    expect(stored.lastSyncedAt!.isAtSameMomentAs(t), isTrue);
  });

  test('setEnabled toggles only the flag', () async {
    await repo.upsert(sample);
    await repo.setEnabled('s1', enabled: false);
    var stored = (await repo.getAll()).single;
    expect(stored.enabled, isFalse);
    expect(stored.name, '测试源');
    await repo.setEnabled('s1', enabled: true);
    stored = (await repo.getAll()).single;
    expect(stored.enabled, isTrue);
  });

  test('remove deletes the subscription', () async {
    await repo.upsert(sample);
    await repo.remove('s1');
    expect(await repo.getAll(), isEmpty);
  });

  test('watchAll emits updates', () async {
    final emissions = <List<Subscription>>[];
    final sub = repo.watchAll().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await repo.upsert(sample);
    await pumpEventQueue();
    expect(emissions, hasLength(greaterThanOrEqualTo(2)));
    expect(emissions.first, isEmpty);
    expect(emissions.last.single.id, 's1');
  });
}
