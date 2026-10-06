import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/player/application/catchup_url.dart';

void main() {
  final start = DateTime.utc(2026, 10, 6, 12);
  final programme = EpgProgram(
    channelId: 'cctv1',
    title: '新闻联播',
    start: start,
    stop: start.add(const Duration(minutes: 30)),
  );
  final now = start.add(const Duration(minutes: 10));

  test('substitutes the original utc and timestamp spellings', () {
    final url = buildCatchupUrl(
      '?utc={utc}'
      '&ts=${'{timestamp}'}'
      '&dollar-utc=${r'${utc}'}'
      '&dollar-ts=${r'${timestamp}'}',
      programme,
      now: now,
    );
    expect(
      url,
      '?utc=${start.toIso8601String()}'
      '&ts=${start.millisecondsSinceEpoch ~/ 1000}'
      '&dollar-utc=${start.toIso8601String()}'
      '&dollar-ts=${start.millisecondsSinceEpoch ~/ 1000}',
    );
  });

  test('substitutes utcend/timestampend without corrupting utc', () {
    // `${utc}` is a prefix of `${utcend}`: the longer token must win.
    final url = buildCatchupUrl(
      '${'{utcend}'}|${r'${utcend}'}|${'{utc}'}',
      programme,
      now: now,
    );
    final endIso = programme.stop.toUtc().toIso8601String();
    expect(url, '$endIso|$endIso|${start.toIso8601String()}');
  });

  test('substitutes start, stop and duration', () {
    final url = buildCatchupUrl(
      '?start=${'{start}'}&stop=${'{stop}'}&duration=${'{duration}'}',
      programme,
      now: now,
    );
    expect(
      url,
      '?start=${start.millisecondsSinceEpoch ~/ 1000}'
      '&stop=${programme.stop.millisecondsSinceEpoch ~/ 1000}'
      '&duration=1800',
    );
  });

  test('offset is the seconds between now and the programme start', () {
    final url = buildCatchupUrl('?offset=${'{offset}'}', programme, now: now);
    expect(url, '?offset=600');
  });

  test('offset clamps to zero for programmes not yet started', () {
    final url = buildCatchupUrl(
      '?offset=${'{offset}'}',
      programme,
      now: start.subtract(const Duration(minutes: 5)),
    );
    expect(url, '?offset=0');
  });

  test('a template without placeholders passes through unchanged', () {
    const template = 'http://example.com/static.mp4';
    expect(buildCatchupUrl(template, programme, now: now), template);
  });
}
