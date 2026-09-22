import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = M3uPlaylistParser();

  group('M3uPlaylistParser', () {
    test('parses header EPG url and channels with attributes', () {
      const content = '''
#EXTM3U x-tvg-url="https://example.com/epg.xml,https://example.com/e2.xml"
#EXTINF:-1 tvg-id="cctv1" tvg-name="CCTV-1" tvg-logo="https://example.com/c1.png" group-title="央视",CCTV-1 综合
http://example.com/cctv1.m3u8
#EXTINF:-1 tvg-id="cctv2" group-title="央视",CCTV-2 财经
#EXTVLCOPT:http-user-agent=Mozilla/5.0
http://example.com/cctv2.m3u8
''';
      final result = parser.parse(const RawPlaylist(content: content));

      expect(result.epgUrl, Uri.parse('https://example.com/epg.xml'));
      expect(result.channels, hasLength(2));

      final c1 = result.channels[0];
      expect(c1.name, 'CCTV-1 综合');
      expect(c1.tvgId, 'cctv1');
      expect(c1.logoUrl, 'https://example.com/c1.png');
      expect(c1.groupTitle, '央视');

      final c2 = result.channels[1];
      expect(c2.name, 'CCTV-2 财经');
      expect(c2.userAgent, 'Mozilla/5.0');
      expect(c2.referrer, isNull);
    });

    test('parses catchup attributes', () {
      const content = '''
#EXTINF:-1 tvg-id="a" catchup="default" catchup-days="7" catchup-source="http://example.com/catchup?utc={utc}",频道A
http://example.com/a.m3u8
''';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.catchupSource, 'http://example.com/catchup?utc={utc}');
      expect(ch.catchupDays, 7);
    });

    test('names bare url lines from the url path', () {
      const content = 'http://example.com/live/ChannelB.m3u8\n';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.name, 'ChannelB.m3u8');
    });

    test('falls back to a default name when EXTINF has no comma', () {
      const content = '''
#EXTINF:-1 tvg-id="lonely"
http://example.com/x.m3u8
''';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.name, '未命名频道');
      expect(ch.tvgId, 'lonely');
    });

    test('skips malformed and comment lines without throwing', () {
      const content = '''
#EXTM3U
# a stray comment
#EXTINF:not-a-duration,坏行

#EXTINF:-1,正常
http://example.com/ok.m3u8
''';
      final result = parser.parse(const RawPlaylist(content: content));
      expect(result.channels, hasLength(1));
      expect(result.channels.single.name, '正常');
    });

    test('empty input yields empty playlist', () {
      final result = parser.parse(const RawPlaylist(content: ''));
      expect(result.channels, isEmpty);
      expect(result.epgUrl, isNull);
    });
  });
}
