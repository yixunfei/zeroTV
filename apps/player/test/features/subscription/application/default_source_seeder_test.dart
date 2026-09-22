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

  test('seeds exactly once on first launch', () async {
    final seeder = await seederWith({});
    expect(await seeder.seedIfNeeded(), isTrue);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.name, DefaultSubscription.name);
    expect(all.single.uri, DefaultSubscription.candidates.first);

    // Second call (same launch or next): no duplicate.
    expect(await seeder.seedIfNeeded(), isFalse);
    expect(await repo.getAll(), hasLength(1));
  });

  test('does not resurrect a deleted default source on next launch', () async {
    var seeder = await seederWith({});
    await seeder.seedIfNeeded();
    await repo.remove((await repo.getAll()).single.id);

    // Next launch: flag persisted, store empty — must stay empty.
    seeder = await seederWith({DefaultSourceSeeder.seededKey: true});
    expect(await seeder.seedIfNeeded(), isFalse);
    expect(await repo.getAll(), isEmpty);
  });

  test(
    'store with existing subscriptions is marked seeded, no insert',
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
      expect(await seeder.seedIfNeeded(), isFalse);
      expect(await repo.getAll(), hasLength(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DefaultSourceSeeder.seededKey), isTrue);
    },
  );
}
