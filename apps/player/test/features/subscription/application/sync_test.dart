import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:zerotv_player/core/database/app_database.dart' as db;
import 'package:zerotv_player/features/channel/data/drift_channel_repository.dart';
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
  });
}
