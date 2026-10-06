import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/channel/data/drift_channel_repository.dart';
import 'package:zerotv_player/features/subscription/application/add_subscription.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/sync_subscription.dart';
import 'package:zerotv_player/features/subscription/data/drift_subscription_repository.dart';
import 'package:zerotv_player/features/subscription/data/subscription_source_factory.dart';

const _sampleM3u = '''
#EXTM3U x-tvg-url="https://example.com/epg.xml"
#EXTINF:-1 tvg-id="cctv1" group-title="央视",CCTV-1
http://example.com/1.m3u8
#EXTINF:-1 group-title="卫视",湖南卫视
http://example.com/2.m3u8
''';

const _m3uWithAds = '''
#EXTM3U
#EXTINF:-1 group-title="更新时间",每日更新请关注公众号
http://example.com/ad1.m3u8
#EXTINF:-1 group-title="推广",支持作者 扫码打赏
http://example.com/ad2.m3u8
#EXTINF:-1 group-title="央视",CCTV-1
http://example.com/1.m3u8
''';

class _FakeSource implements SubscriptionSource {
  const _FakeSource(this._onFetch);

  final Future<RawPlaylist> Function() _onFetch;

  @override
  Future<RawPlaylist> fetch() => _onFetch();
}

class _FakeFactory implements SubscriptionSourceFactory {
  _FakeFactory(this._onFetch);

  final Future<RawPlaylist> Function() _onFetch;

  @override
  SubscriptionSource forSubscription(Subscription subscription) {
    return _FakeSource(_onFetch);
  }
}

void main() {
  late db.AppDatabase database;
  late DriftSubscriptionRepository subscriptions;
  late DriftChannelRepository channels;

  const sub = Subscription(
    id: 's1',
    name: '源',
    kind: SubscriptionKind.remoteUrl,
    uri: 'https://example.com/a.m3u8',
  );

  SyncSubscription buildSync(Future<RawPlaylist> Function() onFetch) {
    return SyncSubscription(
      sources: _FakeFactory(onFetch),
      parser: const M3uPlaylistParser(),
      subscriptions: subscriptions,
      channels: channels,
    );
  }

  setUp(() {
    database = db.AppDatabase.memory();
    subscriptions = DriftSubscriptionRepository(database);
    channels = DriftChannelRepository(database);
  });

  tearDown(() => database.close());

  test('sync stores channels, marks synced and returns the result', () async {
    await subscriptions.upsert(sub);
    final result = await buildSync(
      () async => const RawPlaylist(content: _sampleM3u),
    )(sub);

    expect(result.channelCount, 2);
    expect(result.epgUrl, Uri.parse('https://example.com/epg.xml'));
    expect(await channels.watchAll().first, hasLength(2));
    final stored = (await subscriptions.getAll()).single;
    expect(stored.lastSyncedAt, isNotNull);
    expect(stored.isDue, isFalse);
  });

  test(
    'sync offers the playlist-advertised EPG URL to the adoption callback',
    () async {
      await subscriptions.upsert(sub);
      final adopted = <Uri>[];
      final sync = SyncSubscription(
        sources: _FakeFactory(
          () async => const RawPlaylist(content: _sampleM3u),
        ),
        parser: const M3uPlaylistParser(),
        subscriptions: subscriptions,
        channels: channels,
        adoptEpgUrl: (url) async => adopted.add(url),
      );

      await sync(sub);

      expect(adopted, [Uri.parse('https://example.com/epg.xml')]);
    },
  );

  test(
    'a playlist without an EPG pointer never invokes the callback',
    () async {
      await subscriptions.upsert(sub);
      const noEpg = '''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" group-title="央视",CCTV-1
http://example.com/1.m3u8
''';
      var invoked = false;
      final sync = SyncSubscription(
        sources: _FakeFactory(() async => const RawPlaylist(content: noEpg)),
        parser: const M3uPlaylistParser(),
        subscriptions: subscriptions,
        channels: channels,
        adoptEpgUrl: (_) async => invoked = true,
      );

      await sync(sub);

      expect(invoked, isFalse);
    },
  );

  test('an adoption failure does not fail the sync', () async {
    await subscriptions.upsert(sub);
    final sync = SyncSubscription(
      sources: _FakeFactory(
        () async => const RawPlaylist(content: _sampleM3u),
      ),
      parser: const M3uPlaylistParser(),
      subscriptions: subscriptions,
      channels: channels,
      adoptEpgUrl: (_) async => throw StateError('settings unavailable'),
    );

    final result = await sync(sub);

    // Channels are stored and the sync still reports success.
    expect(result.channelCount, 2);
    expect(await channels.watchAll().first, hasLength(2));
  });

  test('failed sync preserves previously stored channels', () async {
    await subscriptions.upsert(sub);
    await buildSync(() async => const RawPlaylist(content: _sampleM3u))(sub);
    final firstSyncAt = (await subscriptions.getAll()).single.lastSyncedAt;

    await expectLater(
      buildSync(() async => throw Exception('network down'))(sub),
      throwsA(isA<Exception>()),
    );

    expect(await channels.watchAll().first, hasLength(2));
    expect(
      (await subscriptions.getAll()).single.lastSyncedAt,
      firstSyncAt,
    );
  });

  test(
    'empty or HTML sync preserves existing channels and timestamp',
    () async {
      await subscriptions.upsert(sub);
      await buildSync(() async => const RawPlaylist(content: _sampleM3u))(sub);
      final before = (await subscriptions.getAll()).single.lastSyncedAt;
      for (final content in ['', '#EXTM3U', '<html>error</html>']) {
        await expectLater(
          buildSync(() async => RawPlaylist(content: content))(sub),
          throwsA(isA<Exception>()),
        );
        expect(await channels.watchAll().first, hasLength(2));
        expect((await subscriptions.getAll()).single.lastSyncedAt, before);
      }
    },
  );

  test('drops ad/promotion entries at sync time', () async {
    await subscriptions.upsert(sub);
    final result = await buildSync(
      () async => const RawPlaylist(content: _m3uWithAds),
    )(sub);

    expect(result.channelCount, 1);
    final stored = await channels.watchAll().first;
    expect(stored.single.name, 'CCTV-1');
  });

  test('built-in iptv-org sources keep entries with broad names', () async {
    const iptvOrgSub = Subscription(
      id: 'io1',
      name: 'iptv-org · 全球频道',
      kind: SubscriptionKind.remoteUrl,
      uri: 'https://iptv-org.github.io/iptv/index.m3u',
      channelGroupPrefix: '国际',
    );
    await subscriptions.upsert(iptvOrgSub);
    const playlist = '''
#EXTM3U
#EXTINF:-1 group-title="News",NASA TV www.nasa.gov
https://example.com/nasa.m3u8
#EXTINF:-1 group-title="News",CNN International
https://example.com/cnn.m3u8
''';
    await buildSync(() async => const RawPlaylist(content: playlist))(
      iptvOrgSub,
    );

    final stored = await channels.watchAll().first;
    expect(stored, hasLength(2));
    expect(stored.first.name, 'NASA TV www.nasa.gov');
    expect(stored.map((c) => c.groupTitle), everyElement('国际 · News'));
  });

  test('applies the channel group prefix of built-in sources', () async {
    const builtinSub = Subscription(
      id: 'b1',
      name: '默认源 · vbskycn/iptv',
      kind: SubscriptionKind.remoteUrl,
      uri:
          'https://raw.githubusercontent.com/vbskycn/iptv/refs/heads/master/tv/iptv4.m3u',
      channelGroupPrefix: '综合',
    );
    await subscriptions.upsert(builtinSub);
    await buildSync(() async => const RawPlaylist(content: _sampleM3u))(
      builtinSub,
    );

    final stored = await channels.watchAll().first;
    expect(stored.map((c) => c.groupTitle), ['综合 · 央视', '综合 · 卫视']);
  });

  test('ignores the group prefix for user-added subscriptions', () async {
    await subscriptions.upsert(
      const Subscription(
        id: 'u1',
        name: '用户源',
        kind: SubscriptionKind.remoteUrl,
        uri: 'https://example.com/user.m3u8',
        channelGroupPrefix: '不应生效',
      ),
    );
    await buildSync(() async => const RawPlaylist(content: _sampleM3u))(
      (await subscriptions.getAll()).single,
    );

    final stored = await channels.watchAll().first;
    expect(stored.map((c) => c.groupTitle), ['央视', '卫视']);
  });

  test('pasted-text import drops ad entries like a regular sync', () async {
    final add = AddSubscription(
      subscriptions: subscriptions,
      channels: channels,
      parser: const M3uPlaylistParser(),
      sync: buildSync(() async => throw StateError('unused')),
    );

    final result = await add.fromText(name: '粘贴源', content: _m3uWithAds);

    expect(result.channelCount, 1);
    final stored = await channels.watchAll().first;
    expect(stored.single.name, 'CCTV-1');
  });

  group('AutoSyncService', () {
    test('syncs only due and enabled subscriptions', () async {
      await subscriptions.upsert(sub); // due: never synced
      await subscriptions.upsert(
        const Subscription(
          id: 's2',
          name: '不到期',
          kind: SubscriptionKind.remoteUrl,
          uri: 'https://example.com/b.m3u8',
        ),
      );
      await subscriptions.markSynced('s2', DateTime.now()); // not due
      await subscriptions.upsert(
        const Subscription(
          id: 's3',
          name: '停用',
          kind: SubscriptionKind.remoteUrl,
          uri: 'https://example.com/c.m3u8',
          enabled: false,
        ),
      );

      final service = AutoSyncService(
        subscriptions: subscriptions,
        sync: buildSync(() async => const RawPlaylist(content: _sampleM3u)),
      );
      final failures = await service.syncDue();

      expect(failures, isEmpty);
      expect(await channels.watchBySubscription('s1').first, hasLength(2));
      expect(await channels.watchBySubscription('s2').first, isEmpty);
      expect(await channels.watchBySubscription('s3').first, isEmpty);
    });

    test('collects failures without aborting the pass', () async {
      await subscriptions.upsert(sub);
      final service = AutoSyncService(
        subscriptions: subscriptions,
        sync: buildSync(() async => throw Exception('boom')),
      );
      final failures = await service.syncDue();
      expect(failures, hasLength(1));
      expect(failures.single.subscriptionId, 's1');
      expect(failures.single.error, contains('boom'));
    });

    test('syncAll syncs every syncable subscription, ignoring schedule '
        'and the auto-sync toggle', () async {
      await subscriptions.upsert(sub); // due: never synced
      await subscriptions.upsert(
        const Subscription(
          id: 's2',
          name: '不到期',
          kind: SubscriptionKind.remoteUrl,
          uri: 'https://example.com/b.m3u8',
        ),
      );
      await subscriptions.markSynced('s2', DateTime.now()); // not due
      await subscriptions.upsert(
        const Subscription(
          id: 's3',
          name: '停用自动同步',
          kind: SubscriptionKind.remoteUrl,
          uri: 'https://example.com/c.m3u8',
          enabled: false,
        ),
      );
      await subscriptions.upsert(
        const Subscription(
          id: 'manual',
          name: '我的频道',
          kind: SubscriptionKind.manual,
          enabled: false,
        ),
      );

      final service = AutoSyncService(
        subscriptions: subscriptions,
        sync: buildSync(() async => const RawPlaylist(content: _sampleM3u)),
      );
      final failures = await service.syncAll();

      expect(failures, isEmpty);
      for (final id in ['s1', 's2', 's3']) {
        expect(await channels.watchBySubscription(id).first, hasLength(2));
      }
      // Manual subscriptions are never touched by remote sync.
      expect(await channels.watchBySubscription('manual').first, isEmpty);
    });
  });
}
