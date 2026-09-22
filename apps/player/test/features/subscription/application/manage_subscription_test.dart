import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/application/manage_subscription.dart';

import '../../../helpers/fake_subscription_repository.dart';

void main() {
  late FakeSubscriptionRepository repo;
  late ManageSubscription manage;

  const sample = Subscription(
    id: 's1',
    name: '旧名',
    kind: SubscriptionKind.remoteUrl,
    uri: 'https://example.com/a.m3u8',
  );

  setUp(() {
    repo = FakeSubscriptionRepository([sample]);
    manage = ManageSubscription(subscriptions: repo);
  });

  test('rename trims and persists the new name', () async {
    await manage.rename('s1', '  新名  ');
    expect((await repo.getAll()).single.name, '新名');
  });

  test('rename rejects blank names', () {
    expect(() => manage.rename('s1', '   '), throwsArgumentError);
    expect(() => manage.rename('s1', ''), throwsArgumentError);
  });

  test('setEnabled forwards to the repository', () async {
    await manage.setEnabled('s1', enabled: false);
    expect((await repo.getAll()).single.enabled, isFalse);
  });

  test('remove deletes the subscription', () async {
    await manage.remove('s1');
    expect(await repo.getAll(), isEmpty);
  });
}
