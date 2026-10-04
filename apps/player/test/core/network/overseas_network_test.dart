import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/network/overseas_network.dart';

void main() {
  test('does not classify generic public CDN hosts as overseas', () {
    expect(
      isLikelyOverseasStream('https://cdn.example.com/live.m3u8'),
      isFalse,
    );
    expect(
      needsOverseasNetworkHint(
        const Channel(
          name: 'CCTV',
          streamUrl: 'https://cdn.example.com/live.m3u8',
          groupTitle: '综合',
        ),
      ),
      isFalse,
    );
  });

  test('international source group always gets a hint', () {
    expect(
      needsOverseasNetworkHint(
        const Channel(
          name: 'News',
          streamUrl: 'https://cdn.example.com/live.m3u8',
          groupTitle: '国际 · 新闻',
        ),
      ),
      isTrue,
    );
  });

  test('known overseas country-code hosts get a hint', () {
    expect(isLikelyOverseasStream('https://example.jp/live.m3u8'), isTrue);
    expect(isLikelyOverseasStream('https://example.cn/live.m3u8'), isFalse);
    expect(
      needsOverseasNetworkHint(
        const Channel(
          name: 'Domestic channel',
          streamUrl: 'https://example.jp/live.m3u8',
          groupTitle: '综合',
        ),
      ),
      isFalse,
    );
  });
}
