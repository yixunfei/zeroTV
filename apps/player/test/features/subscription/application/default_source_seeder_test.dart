import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/features/subscription/application/default_source_seeder.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';

import '../../../helpers/fake_subscription_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSubscriptionRepository repo;

  setUp(() => repo = FakeSubscriptionRepository());

  Future<DefaultSourceSeeder> seederWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return DefaultSourceSeeder(repo, await SharedPreferences.getInstance());
  }

  test('seeds all built-in sources exactly once on first launch', () async {
    final seeder = await seederWith({});
    expect(await seeder.seedIfNeeded(), isTrue);
    final all = await repo.getAll();
    expect(all, hasLength(DefaultSubscription.sources.length));
    expect(all.first.name, DefaultSubscription.sources.first.name);
    expect(all.first.uri, DefaultSubscription.sources.first.candidates.first);
    expect(
      all.first.channelGroupPrefix,
      DefaultSubscription.sources.first.channelGroupPrefix,
    );

    // Second call (same launch or next): no duplicate.
    expect(await seeder.seedIfNeeded(), isFalse);
    expect(await repo.getAll(), hasLength(DefaultSubscription.sources.length));
  });

  test('does not resurrect a deleted default source on next launch', () async {
    var seeder = await seederWith({});
    await seeder.seedIfNeeded();
    for (final s in await repo.getAll()) {
      await repo.remove(s.id);
    }

    // Next launch: version persisted, store empty — must stay empty.
    seeder = await seederWith({
      DefaultSourceSeeder.seededVersionKey: DefaultSubscription.catalogVersion,
    });
    expect(await seeder.seedIfNeeded(), isFalse);
    expect(await repo.getAll(), isEmpty);
  });

  test(
    'store with existing subscriptions gets only newer catalogue additions',
    () async {
      await repo.upsert(
        const Subscription(
          id: 'own',
          name: '用户自有源',
          kind: SubscriptionKind.remoteUrl,
          uri: 'https://example.com/a.m3u8',
        ),
      );
      final seeder = await seederWith({});
      final added = await seeder.seedIfNeeded();
      final addedSources = DefaultSubscription.sources
          .where((s) => s.sinceVersion > 1)
          .toList();
      expect(addedSources, isNotEmpty);
      expect(added, isTrue);
      expect(await repo.getAll(), hasLength(1 + addedSources.length));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(DefaultSourceSeeder.seededVersionKey),
        DefaultSubscription.catalogVersion,
      );
    },
  );

  test('legacy boolean flag counts as version 1', () async {
    final seeder = await seederWith({'default_source_seeded': true});
    // All v1 sources stay absent, v2 additions arrive.
    expect(await seeder.seedIfNeeded(), isTrue);
    final all = await repo.getAll();
    expect(
      all.map((s) => s.name),
      containsAll([
        for (final s in DefaultSubscription.sources)
          if (s.sinceVersion > 1) s.name,
      ]),
    );
    expect(
      all.map((s) => s.name),
      isNot(
        contains(DefaultSubscription.sources.first.name),
      ),
    );
  });

  test('upgrade does not duplicate a manually added new source', () async {
    final source = DefaultSubscription.sources.last;
    await repo.upsert(
      Subscription(
        id: 'manual',
        name: source.name,
        kind: SubscriptionKind.remoteUrl,
        uri: source.candidates.first,
      ),
    );
    final seeder = await seederWith({DefaultSourceSeeder.seededVersionKey: 1});
    await seeder.seedIfNeeded();
    final withUri = (await repo.getAll())
        .where((s) => s.uri == source.candidates.first)
        .toList();
    expect(withUri, hasLength(1));
  });

  test('upgrade removes retired built-in sources by exact URL', () async {
    final retired = DefaultSubscription.retiredUris.first;
    await repo.upsert(
      Subscription(
        id: 'retired',
        name: '旧内置源',
        kind: SubscriptionKind.remoteUrl,
        uri: retired,
      ),
    );
    final seeder = await seederWith({
      DefaultSourceSeeder.seededVersionKey: DefaultSubscription.catalogVersion,
    });

    await seeder.seedIfNeeded();

    expect(await repo.getAll(), isEmpty);
  });
}
