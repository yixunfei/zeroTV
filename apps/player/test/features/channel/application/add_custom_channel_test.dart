import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/add_custom_channel.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_subscription_repository.dart';

void main() {
  late FakeSubscriptionRepository subscriptions;
  late _RecordingChannelRepository channels;
  late AddCustomChannel add;

  setUp(() {
    subscriptions = FakeSubscriptionRepository();
    channels = _RecordingChannelRepository();
    add = AddCustomChannel(subscriptions: subscriptions, channels: channels);
  });

  test('creates a manual subscription on the first channel', () async {
    await add(
      const Channel(name: 'CCTV-1', streamUrl: 'http://a/1', groupTitle: '央视'),
    );

    final subs = await subscriptions.getAll();
    expect(subs, hasLength(1));
    expect(subs.single.kind, SubscriptionKind.manual);
    expect(subs.single.name, manualSubscriptionName);
    expect(subs.single.enabled, isFalse);
    expect(channels.upserted, hasLength(1));
    expect(channels.upserted.single.$1, subs.single.id);
    expect(channels.upserted.single.$2.name, 'CCTV-1');
  });

  test('reuses the existing manual subscription', () async {
    await add(const Channel(name: 'A', streamUrl: 'http://a/1'));
    await add(const Channel(name: 'B', streamUrl: 'http://a/2'));

    final subs = await subscriptions.getAll();
    expect(subs, hasLength(1));
    expect(channels.upserted, hasLength(2));
    expect(channels.upserted[0].$1, channels.upserted[1].$1);
  });

  test('does not create a manual subscription when one exists', () async {
    await subscriptions.upsert(
      const Subscription(
        id: 'existing',
        name: '我的频道',
        kind: SubscriptionKind.manual,
      ),
    );
    await add(const Channel(name: 'A', streamUrl: 'http://a/1'));

    expect(await subscriptions.getAll(), hasLength(1));
    expect(channels.upserted.single.$1, 'existing');
  });
}

class _RecordingChannelRepository extends FakeChannelRepository {
  final upserted = <(String, Channel)>[];

  @override
  Future<void> upsertManual(String subscriptionId, Channel channel) async {
    upserted.add((subscriptionId, channel));
  }
}
