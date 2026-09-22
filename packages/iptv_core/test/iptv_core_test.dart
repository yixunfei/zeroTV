import 'package:iptv_core/iptv_core.dart';
import 'package:test/test.dart';

void main() {
  group('Subscription', () {
    test('defaults to 6h refresh interval and enabled', () {
      const sub = Subscription(
        id: 'a',
        name: 'demo',
        kind: SubscriptionKind.remoteUrl,
      );
      expect(sub.refreshInterval, const Duration(hours: 6));
      expect(sub.enabled, isTrue);
      expect(sub.lastSyncedAt, isNull);
    });
  });

  group('Channel', () {
    test('optional metadata defaults to null', () {
      const ch = Channel(
        name: 'CCTV-1',
        streamUrl: 'http://example.com/1.m3u8',
      );
      expect(ch.tvgId, isNull);
      expect(ch.groupTitle, isNull);
    });

    test('identity key prefers tvgId over name', () {
      const withId = Channel(
        name: 'CCTV-1 综合',
        streamUrl: 'http://a/1',
        tvgId: 'cctv1',
      );
      const withoutId = Channel(name: ' CCTV-2 ', streamUrl: 'http://a/2');
      expect(withId.identityKey, 'cctv1');
      expect(withoutId.identityKey, 'cctv-2');
    });

    test('http headers contain only the provided values', () {
      const bare = Channel(name: 'a', streamUrl: 'http://a/1');
      const full = Channel(
        name: 'a',
        streamUrl: 'http://a/1',
        userAgent: 'UA',
        referrer: 'REF',
      );
      expect(bare.httpHeaders, isEmpty);
      expect(
        full.httpHeaders,
        {'User-Agent': 'UA', 'Referer': 'REF'},
      );
    });
  });

  group('Subscription.isDue', () {
    const sub = Subscription(
      id: 'a',
      name: 'demo',
      kind: SubscriptionKind.remoteUrl,
    );

    test('is due when never synced', () {
      expect(sub.isDue, isTrue);
    });

    test('is not due right after a sync', () {
      final synced = Subscription(
        id: 'a',
        name: 'demo',
        kind: SubscriptionKind.remoteUrl,
        lastSyncedAt: DateTime.now(),
      );
      expect(synced.isDue, isFalse);
    });

    test('is due after the refresh interval elapsed', () {
      final stale = Subscription(
        id: 'a',
        name: 'demo',
        kind: SubscriptionKind.remoteUrl,
        lastSyncedAt: DateTime.now().subtract(const Duration(hours: 7)),
      );
      expect(stale.isDue, isTrue);
    });
  });

  group('ProbeResult', () {
    test('carries classification fields', () {
      final r = ProbeResult(
        url: 'http://x',
        status: ProbeStatus.ok,
        checkedAt: DateTime(2026),
        latency: const Duration(milliseconds: 120),
        httpStatus: 200,
      );
      expect(r.status, ProbeStatus.ok);
      expect(r.latency, const Duration(milliseconds: 120));
    });
  });

  group('EpgFeed', () {
    test('empty feed is empty', () {
      expect(EpgFeed.empty.channels, isEmpty);
      expect(EpgFeed.empty.programmes, isEmpty);
    });
  });
}
