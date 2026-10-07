import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:test/test.dart';

void main() {
  test('encoding spaces preserves existing escapes and signed queries', () {
    final channel = const M3uPlaylistParser()
        .parse(
          const RawPlaylist(
            content:
                '#EXTINF:-1,News\n'
                'https://example.com/a%2Fb c.ts?token=x%2By%3D',
          ),
        )
        .channels
        .single;

    expect(
      channel.streamUrl,
      'https://example.com/a%2Fb%20c.ts?token=x%2By%3D',
    );
  });
}
