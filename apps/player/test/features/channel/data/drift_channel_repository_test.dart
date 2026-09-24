import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/channel/data/drift_channel_repository.dart';
import 'package:zerotv_player/features/subscription/data/drift_subscription_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftChannelRepository channels;
  late DriftSubscriptionRepository subscriptions;

  const seedChannels = [
    Channel(
      name: 'CCTV-1',
      streamUrl: 'http://a/1',
      tvgId: 'cctv1',
      groupTitle: '央视',
    ),
    Channel(name: 'CCTV-2', streamUrl: 'http://a/2', groupTitle: '央视'),
    Channel(name: '湖南卫视', streamUrl: 'http://a/3', groupTitle: '卫视'),
    Channel(name: '散装台', streamUrl: 'http://a/4'),
  ];

  setUp(() async {
    database = db.AppDatabase.memory();
    channels = DriftChannelRepository(database);
    subscriptions = DriftSubscriptionRepository(database);
    await subscriptions.upsert(
      const Subscription(
        id: 's1',
        name: '源',
        kind: SubscriptionKind.remoteUrl,
        uri: 'https://example.com/a.m3u8',
      ),
    );
  });

  tearDown(() => database.close());

  test('replaceAll stores channels in source order', () async {
    await channels.replaceAll('s1', seedChannels);
    final all = await channels.watchAll().first;
    expect(
      all.map((c) => c.name).toList(),
      ['CCTV-1', 'CCTV-2', '湖南卫视', '散装台'],
    );
    expect(all.first.tvgId, 'cctv1');
    expect(all.last.groupTitle, isNull);
  });

  test('replaceAll replaces instead of appending', () async {
    await channels.replaceAll('s1', seedChannels);
    await channels.replaceAll('s1', seedChannels.take(1).toList());
    final all = await channels.watchAll().first;
    expect(all, hasLength(1));
    expect(all.single.name, 'CCTV-1');
  });

  test('watchAllGroups maps null group to the ungrouped label', () async {
    await channels.replaceAll('s1', seedChannels);
    final groups = await channels.watchAllGroups().first;
    expect(groups, hasLength(3));
    expect(groups, containsAll(['央视', '卫视', ungroupedGroupLabel]));
  });

  test('watchBySubscription filters by subscription', () async {
    await subscriptions.upsert(
      const Subscription(
        id: 's2',
        name: '源2',
        kind: SubscriptionKind.remoteUrl,
        uri: 'https://example.com/b.m3u8',
      ),
    );
    await channels.replaceAll('s1', seedChannels.take(2).toList());
    await channels.replaceAll('s2', seedChannels.skip(2).take(1).toList());
    expect(await channels.watchBySubscription('s1').first, hasLength(2));
    expect(await channels.watchBySubscription('s2').first, hasLength(1));
    expect(await channels.watchAll().first, hasLength(3));
  });

  test('removing a subscription cascades its channels', () async {
    await channels.replaceAll('s1', seedChannels);
    await subscriptions.remove('s1');
    expect(await channels.watchAll().first, isEmpty);
  });

  test('watchCountsBySubscription groups counts per subscription', () async {
    await subscriptions.upsert(
      const Subscription(
        id: 's2',
        name: '源2',
        kind: SubscriptionKind.remoteUrl,
        uri: 'https://example.com/b.m3u8',
      ),
    );
    await channels.replaceAll('s1', seedChannels.take(3).toList());
    await channels.replaceAll('s2', seedChannels.skip(3).toList());

    final counts = await channels.watchCountsBySubscription().first;
    expect(counts, {'s1': 3, 's2': 1});

    await channels.replaceAll('s1', seedChannels.take(1).toList());
    final updated = await channels.watchCountsBySubscription().first;
    expect(updated, {'s1': 1, 's2': 1});
  });

  group('upsertManual / deleteManual', () {
    test('upsertManual appends a new channel in position order', () async {
      await channels.upsertManual(
        's1',
        const Channel(name: 'A', streamUrl: 'http://a/1'),
      );
      await channels.upsertManual(
        's1',
        const Channel(name: 'B', streamUrl: 'http://a/2'),
      );

      final all = await channels.watchAll().first;
      expect(all.map((c) => c.name).toList(), ['A', 'B']);
    });

    test(
      'upsertManual replaces a channel with the same identity key',
      () async {
        await channels.upsertManual(
          's1',
          const Channel(name: 'A', streamUrl: 'http://a/1'),
        );
        await channels.upsertManual(
          's1',
          const Channel(name: 'A', streamUrl: 'http://a/updated'),
        );

        final all = await channels.watchAll().first;
        expect(all, hasLength(1));
        expect(all.single.streamUrl, 'http://a/updated');
      },
    );

    test('upsertManual keeps replacement at the original position', () async {
      await channels.upsertManual(
        's1',
        const Channel(name: 'A', streamUrl: 'http://a/1'),
      );
      await channels.upsertManual(
        's1',
        const Channel(name: 'B', streamUrl: 'http://a/2'),
      );
      await channels.upsertManual(
        's1',
        const Channel(name: 'A', streamUrl: 'http://a/updated'),
      );

      final all = await channels.watchAll().first;
      expect(all.map((c) => c.name).toList(), ['A', 'B']);
      expect(all.first.streamUrl, 'http://a/updated');
    });

    test('deleteManual removes by identity key', () async {
      await channels.upsertManual(
        's1',
        const Channel(name: 'A', streamUrl: 'http://a/1', tvgId: 'a'),
      );
      await channels.upsertManual(
        's1',
        const Channel(name: 'B', streamUrl: 'http://a/2', tvgId: 'b'),
      );

      await channels.deleteManual('s1', 'a');
      final all = await channels.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.name, 'B');
    });
  });
}
