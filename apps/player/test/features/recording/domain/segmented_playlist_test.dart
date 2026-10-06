import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/features/recording/domain/segmented_playlist.dart';

void main() {
  test('matches HLS and DASH playlist extensions', () {
    for (final url in [
      'http://example.com/live.m3u8',
      'http://example.com/live.m3u',
      'http://example.com/live.mpd',
      'http://example.com/live.M3U8', // case-insensitive
      'http://example.com/path/live.m3u8',
    ]) {
      expect(isSegmentedPlaylistUrl(url), isTrue, reason: url);
    }
  });

  test('matches a playlist extension followed by a query string', () {
    // The old recorder-side regex required path-final extensions and
    // missed query-bearing URLs; the unified predicate must not.
    expect(
      isSegmentedPlaylistUrl('http://example.com/live.m3u8?token=abc'),
      isTrue,
    );
    expect(
      isSegmentedPlaylistUrl('http://example.com/live.mpd?token=abc'),
      isTrue,
    );
  });

  test('does not match direct streams or other extensions', () {
    for (final url in [
      'http://example.com/live.ts',
      'http://example.com/live.mp4',
      'http://example.com/stream/1001',
      'rtsp://example.com/live',
      'udp://239.0.0.1:1234',
      'http://example.com/', // bare host, empty path
      'not a url at all',
    ]) {
      expect(isSegmentedPlaylistUrl(url), isFalse, reason: url);
    }
  });

  test('extension inside the query is not a playlist by URL alone', () {
    // Path-less URLs with the extension only in the query stay
    // recordable by URL classification; the recorder's content-type
    // check remains the authoritative guard for these.
    expect(
      isSegmentedPlaylistUrl('http://example.com/play?file=x.m3u8'),
      isFalse,
    );
  });
}
