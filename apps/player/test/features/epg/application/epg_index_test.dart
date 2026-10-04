import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';
import 'package:zerotv_player/features/epg/application/epg_index.dart';

void main() {
  NowNext nowNext(String title) {
    final at = DateTime.utc(2026, 9, 24, 12);
    return NowNext(
      now: EpgProgram(
        channelId: 'x',
        title: title,
        start: at,
        stop: at.add(const Duration(hours: 1)),
      ),
    );
  }

  test('matches by tvgId first', () {
    final index = EpgIndex(
      byEpgId: {'cctv1': nowNext('新闻联播')},
      byNormalizedName: const {'cctv-1': 'cctv1'},
    );
    const channel = Channel(
      name: 'CCTV-1',
      streamUrl: 'http://a/1',
      tvgId: 'cctv1',
    );

    expect(index.forChannel(channel)?.now?.title, '新闻联播');
  });

  test('falls back to normalized display name', () {
    final index = EpgIndex(
      byEpgId: {'hunan': nowNext('快乐大本营')},
      byNormalizedName: const {'湖南卫视': 'hunan'},
    );
    const channel = Channel(name: ' 湖南  卫视 ', streamUrl: 'http://a/1');

    expect(index.forChannel(channel)?.now?.title, '快乐大本营');
  });

  test('returns null when nothing matches', () {
    final index = EpgIndex(
      byEpgId: {'cctv1': nowNext('新闻联播')},
      byNormalizedName: const {'cctv-1': 'cctv1'},
    );
    const channel = Channel(name: '未知频道', streamUrl: 'http://a/1');

    expect(index.forChannel(channel), isNull);
  });

  test('empty index reports empty and matches nothing', () {
    expect(EpgIndex.empty.isEmpty, isTrue);
    const channel = Channel(name: 'CCTV-1', streamUrl: 'http://a/1');
    expect(EpgIndex.empty.forChannel(channel), isNull);
  });

  test('normalize lowercases and strips whitespace', () {
    expect(EpgIndex.normalize(' CCTV  1 '), 'cctv1');
  });

  test('epgIdFor prefers tvgId when present in the feed', () {
    final index = EpgIndex(
      byEpgId: {'cctv1': nowNext('新闻联播')},
      byNormalizedName: const {'cctv-1': 'cctv1'},
    );
    const channel = Channel(
      name: 'CCTV-1',
      streamUrl: 'http://a/1',
      tvgId: 'cctv1',
    );
    expect(index.epgIdFor(channel), 'cctv1');
  });

  test('epgIdFor trims whitespace around tvgId', () {
    final index = EpgIndex(
      byEpgId: {'cctv1': nowNext('新闻联播')},
      byNormalizedName: const {},
    );
    const channel = Channel(
      name: 'CCTV-1',
      streamUrl: 'http://a/1',
      tvgId: ' cctv1 ',
    );

    expect(index.epgIdFor(channel), 'cctv1');
  });

  test('epgIdFor falls back to the normalized name', () {
    final index = EpgIndex(
      byEpgId: {'hunan': nowNext('快乐大本营')},
      byNormalizedName: const {'湖南卫视': 'hunan'},
    );
    const channel = Channel(name: '湖南卫视', streamUrl: 'http://a/1');
    expect(index.epgIdFor(channel), 'hunan');
  });

  test('epgIdFor returns tvgId even without programmes in window', () {
    final index = EpgIndex(
      byEpgId: const {},
      byNormalizedName: const {'cctv-1': 'cctv1'},
    );
    const channel = Channel(
      name: 'CCTV-1',
      streamUrl: 'http://a/1',
      tvgId: 'cctv1',
    );
    expect(index.epgIdFor(channel), 'cctv1');
  });

  test('epgIdFor returns null when nothing matches', () {
    const channel = Channel(name: '未知频道', streamUrl: 'http://a/1');
    expect(EpgIndex.empty.epgIdFor(channel), isNull);
  });
}
