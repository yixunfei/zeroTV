import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';

void main() {
  EpgProgram p(String title, int startHour, int stopHour) {
    return EpgProgram(
      channelId: 'c',
      title: title,
      start: DateTime.utc(2026, 9, 24, startHour),
      stop: DateTime.utc(2026, 9, 24, stopHour),
    );
  }

  test('resolve finds the airing programme and the next one', () {
    final guide = EpgGuide(
      from: DateTime.utc(2026, 9, 24, 11, 15),
      to: DateTime.utc(2026, 9, 24, 14),
    );
    final now = guide.resolve([
      p('A', 10, 11),
      p('B', 11, 12),
      p('C', 12, 13),
    ]);

    expect(now.now?.title, 'B');
    expect(now.next?.title, 'C');
  });

  test('resolve returns null now when only future programmes exist', () {
    final guide = EpgGuide(
      from: DateTime.utc(2026, 9, 24, 11, 15),
      to: DateTime.utc(2026, 9, 24, 14),
    );
    final now = guide.resolve([p('C', 12, 13)]);

    expect(now.now, isNull);
    expect(now.next?.title, 'C');
  });

  test('resolve returns null next when the airing programme is last', () {
    final guide = EpgGuide(
      from: DateTime.utc(2026, 9, 24, 11, 15),
      to: DateTime.utc(2026, 9, 24, 14),
    );
    final now = guide.resolve([p('B', 11, 12)]);

    expect(now.now?.title, 'B');
    expect(now.next, isNull);
  });

  test('resolve handles an empty programme list', () {
    final guide = EpgGuide(
      from: DateTime.utc(2026, 9, 24, 11, 15),
      to: DateTime.utc(2026, 9, 24, 14),
    );
    final now = guide.resolve(const []);
    expect(now.now, isNull);
    expect(now.next, isNull);
  });
}
