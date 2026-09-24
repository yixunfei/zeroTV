import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:zerotv_player/features/player/presentation/player_osd.dart';

void main() {
  test('PlayerAspect cycles through all presets and wraps around', () {
    expect(PlayerAspect.contain.next, PlayerAspect.cover);
    expect(PlayerAspect.fitHeight.next, PlayerAspect.contain);
  });

  test('each PlayerAspect maps to a distinct BoxFit', () {
    final fits = PlayerAspect.values.map((a) => a.fit).toSet();
    expect(fits, hasLength(PlayerAspect.values.length));
  });

  test('trackLabel prefers title, then language, then id', () {
    expect(
      trackLabel(const AudioTrack('0', 'English 5.1', 'en')),
      'English 5.1',
    );
    expect(trackLabel(const AudioTrack('1', null, 'zh')), 'zh');
    expect(trackLabel(const AudioTrack('2', null, null)), '2');
    expect(trackLabel(const AudioTrack('3', '  ', null)), '3');
  });

  test('subtitleLabel prefers title, then language, then id', () {
    expect(
      subtitleLabel(const SubtitleTrack('0', '中文', 'zh')),
      '中文',
    );
    expect(subtitleLabel(const SubtitleTrack('1', null, 'en')), 'en');
    expect(subtitleLabel(const SubtitleTrack('2', null, null)), '2');
  });

  test('rate presets include 1.0 and are ascending', () {
    expect(playerRatePresets, contains(1.0));
    final sorted = [...playerRatePresets]..sort();
    expect(playerRatePresets, sorted);
  });
}
