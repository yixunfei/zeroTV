import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = M3uPlaylistParser();

  group('M3uPlaylistParser', () {
    test('keeps commas in names and ignores quoted attribute commas', () {
      final result = parser.parse(
        const RawPlaylist(
          content:
              '#EXTINF:-1 group-title="News,World",News, HD\nhttps://example.com/live',
        ),
      );
      expect(result.channels.single.name, 'News, HD');
    });

    test('resolves relative stream and EPG URLs against the source', () {
      final result = parser.parse(
        RawPlaylist(
          content:
              '#EXTM3U x-tvg-url="../epg.xml"\n'
              '#EXTINF:-1,News\nlive/news.m3u8',
          originUri: Uri.parse('https://example.com/lists/index.m3u'),
        ),
      );
      expect(
        result.channels.single.streamUrl,
        'https://example.com/lists/live/news.m3u8',
      );
      expect(result.epgUrl.toString(), 'https://example.com/epg.xml');
    });

    test(
      'rejects HTML and malformed endpoints',
      () {
        expect(
          parser
              .parse(
                const RawPlaylist(
                  content:
                      '<html><body>Access denied</body></html>\n'
                      'not a URL\nhttp://',
                ),
              )
              .channels,
          isEmpty,
        );
      },
    );

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

    test('catchup mode alone is not treated as a source template', () {
      const content = '''
#EXTINF:-1 catchup="default" catchup-days="3",频道B
http://example.com/b.m3u8
''';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.catchupSource, isNull);
      expect(ch.catchupDays, 3);
    });

    test('EXTVLCOPT before EXTINF still applies to the entry', () {
      const content = '''
#EXTVLCOPT:http-user-agent=Mozilla/5.0
#EXTVLCOPT:http-referrer=https://example.com/
#EXTINF:-1,频道C
http://example.com/c.m3u8
#EXTINF:-1,频道D
http://example.com/d.m3u8
''';
      final result = parser.parse(const RawPlaylist(content: content));
      expect(result.channels, hasLength(2));
      expect(result.channels[0].userAgent, 'Mozilla/5.0');
      expect(result.channels[0].referrer, 'https://example.com/');
      // Options are consumed by the first entry only.
      expect(result.channels[1].userAgent, isNull);
      expect(result.channels[1].referrer, isNull);
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

    test('parses unquoted attribute values', () {
      const content = '''
#EXTINF:-1 tvg-id=cctv1 group-title=News,CCTV-1
http://example.com/cctv1.m3u8
''';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.tvgId, 'cctv1');
      expect(ch.groupTitle, 'News');
      expect(ch.name, 'CCTV-1');
    });

    test('quoted attribute values win over unquoted matches', () {
      const content = '''
#EXTINF:-1 tvg-name="A, B" tvg-id=x,频道
http://example.com/a.m3u8
''';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.tvgId, 'x');
      expect(ch.name, '频道');
    });

    test('percent-encodes stray spaces in stream URLs instead of dropping', () {
      const content = '''
#EXTINF:-1,频道
http://example.com/live/a b.m3u8
''';
      final ch = parser
          .parse(const RawPlaylist(content: content))
          .channels
          .single;
      expect(ch.streamUrl, 'http://example.com/live/a%20b.m3u8');
    });

    test('accepts url-tvg and tvg-url header variants', () {
      final a = parser.parse(
        const RawPlaylist(
          content: '#EXTM3U url-tvg="https://e.example/epg.xml"',
        ),
      );
      expect(a.epgUrl, Uri.parse('https://e.example/epg.xml'));
      final b = parser.parse(
        const RawPlaylist(
          content: '#EXTM3U tvg-url="https://e.example/epg2.xml"',
        ),
      );
      expect(b.epgUrl, Uri.parse('https://e.example/epg2.xml'));
    });

    test(
      'key=value text in the display name is not picked up as attribute',
      () {
        const content = '''
#EXTINF:-1 group-title="News",CCTV-1 tvg-id=injected
http://example.com/a.m3u8
#EXTINF:-1 tvg-name="频道 tvg-id=evil",频道E
http://example.com/b.m3u8
''';
        final result = parser.parse(const RawPlaylist(content: content));
        expect(result.channels, hasLength(2));
        expect(result.channels[0].tvgId, isNull);
        expect(result.channels[0].groupTitle, 'News');
        expect(result.channels[1].tvgId, isNull);
      },
    );

    test('rejects prose and HTML error lines even with an origin', () {
      final result = parser.parse(
        RawPlaylist(
          content:
              'Access denied.\n'
              '<p>Error 503.</p>\n'
              '#EXTINF:-1,正常\n'
              'live/ok.m3u8',
          originUri: Uri.parse('https://example.com/lists/index.m3u'),
        ),
      );
      expect(result.channels, hasLength(1));
      expect(
        result.channels.single.streamUrl,
        'https://example.com/lists/live/ok.m3u8',
      );
    });
  });
}
