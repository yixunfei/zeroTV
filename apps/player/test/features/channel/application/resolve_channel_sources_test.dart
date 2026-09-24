import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/resolve_channel_sources.dart';

void main() {
  const resolver = ResolveChannelSources();

  const channel = Channel(
    name: 'CCTV-1',
    streamUrl: 'http://a/1',
    tvgId: 'cctv1',
  );

  test('returns only the tapped channel when no duplicates exist', () {
    final sources = resolver(channel, const [channel], const {});
    expect(sources.map((c) => c.streamUrl).toList(), ['http://a/1']);
  });

  test('deduplicates sources by URL, tapped source first', () {
    const duplicate = Channel(
      name: 'CCTV-1 HD',
      streamUrl: 'http://b/1',
      tvgId: 'cctv1',
    );
    final sources = resolver(
      channel,
      const [channel, duplicate],
      const {},
    );
    expect(sources.map((c) => c.streamUrl).toList(), [
      'http://a/1',
      'http://b/1',
    ]);
  });

  test('skips same-URL duplicates from other subscriptions', () {
    const sameUrl = Channel(
      name: 'CCTV-1 (镜像)',
      streamUrl: 'http://a/1',
      tvgId: 'cctv1',
    );
    final sources = resolver(channel, const [channel, sameUrl], const {});
    expect(sources, hasLength(1));
  });

  test('promotes a known-good probed source to second place', () {
    const alt = Channel(
      name: 'CCTV-1 HD',
      streamUrl: 'http://b/1',
      tvgId: 'cctv1',
    );
    const alt2 = Channel(
      name: 'CCTV-1 备用',
      streamUrl: 'http://c/1',
      tvgId: 'cctv1',
    );
    final sources = resolver(
      channel,
      const [channel, alt, alt2],
      {
        'cctv1': ProbeResult(
          url: 'http://c/1',
          status: ProbeStatus.ok,
          checkedAt: DateTime.utc(2026, 9, 24, 12),
        ),
      },
    );

    expect(sources.map((c) => c.streamUrl).toList(), [
      'http://a/1', // tapped source stays first
      'http://c/1', // known-good promoted
      'http://b/1',
    ]);
  });

  test('keeps order when the probe is not ok', () {
    const alt = Channel(
      name: 'CCTV-1 HD',
      streamUrl: 'http://b/1',
      tvgId: 'cctv1',
    );
    final sources = resolver(
      channel,
      const [channel, alt],
      {
        'cctv1': ProbeResult(
          url: 'http://b/1',
          status: ProbeStatus.dead,
          checkedAt: DateTime.utc(2026, 9, 24, 12),
        ),
      },
    );

    expect(sources.map((c) => c.streamUrl).toList(), [
      'http://a/1',
      'http://b/1',
    ]);
  });
}
