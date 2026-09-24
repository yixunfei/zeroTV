import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/remove_custom_channel.dart';

import '../../../helpers/fake_channel_repository.dart';
import '../../../helpers/fake_subscription_repository.dart';

void main() {
  late FakeSubscriptionRepository subscriptions;
  late _RecordingChannelRepository channels;
  late RemoveCustomChannel remove;

  setUp(() {
    subscriptions = FakeSubscriptionRepository();
    channels = _RecordingChannelRepository();
    remove = RemoveCustomChannel(
      subscriptions: subscriptions,
      channels: channels,
    );
  });

  test('deletes from the manual subscription when one exists', () async {
    await subscriptions.upsert(
      const Subscription(
        id: 'manual',
        name: '我的频道',
        kind: SubscriptionKind.manual,
      ),
    );

    await remove('cctv1');

    expect(channels.deleted, [('manual', 'cctv1')]);
  });

  test('is a no-op when no manual subscription exists', () async {
    await subscriptions.upsert(
      const Subscription(
        id: 'remote',
        name: '源',
        kind: SubscriptionKind.remoteUrl,
        uri: 'https://example.com/a.m3u8',
      ),
    );

    await remove('cctv1');

    expect(channels.deleted, isEmpty);
  });
}

class _RecordingChannelRepository extends FakeChannelRepository {
  final deleted = <(String, String)>[];

  @override
  Future<void> deleteManual(String subscriptionId, String identityKey) async {
    deleted.add((subscriptionId, identityKey));
  }
}
