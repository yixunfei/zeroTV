import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:xmltv_parser/xmltv_parser.dart';

void main() {
  const parser = XmltvParser();

  const sample = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="test">
  <channel id="cctv1">
    <display-name>CCTV-1</display-name>
    <icon src="https://example.com/c1.png"/>
  </channel>
  <channel id="">
    <display-name>坏频道</display-name>
  </channel>
  <programme channel="cctv1" start="20260921120000 +0800"
             stop="20260921123000 +0800">
    <title>新闻30分</title>
    <desc>午间新闻</desc>
  </programme>
  <programme channel="cctv1" start="bad" stop="20260921130000 +0800">
    <title>坏节目</title>
  </programme>
  <programme channel="cctv1" start="20260921130000 +0800"
             stop="20260921140000 +0800">
  </programme>
</tv>
''';

  group('XmltvParser', () {
    test('parses channels and skips invalid ones', () {
      final feed = parser.parse(sample);
      expect(feed.channels, hasLength(1));
      expect(feed.channels.single.id, 'cctv1');
      expect(feed.channels.single.displayName, 'CCTV-1');
      expect(feed.channels.single.iconUrl, 'https://example.com/c1.png');
    });

    test('parses programmes, skipping entries missing required fields', () {
      final feed = parser.parse(sample);
      expect(feed.programmes, hasLength(1));
      final p = feed.programmes.single;
      expect(p.title, '新闻30分');
      expect(p.description, '午间新闻');
      expect(p.start, DateTime.utc(2026, 9, 21, 4)); // +0800 -> UTC
      expect(p.stop, DateTime.utc(2026, 9, 21, 4, 30));
    });

    test('throws XmlException for malformed documents', () {
      expect(() => parser.parse('<tv><channel'), throwsA(isA<XmlException>()));
    });

    test('fills a missing stop from the next programme on the channel', () {
      final feed = parser.parse('''
<tv>
  <programme channel="cctv1" start="20260921120000 +0800">
    <title>节目A</title>
  </programme>
  <programme channel="cctv1" start="20260921130000 +0800">
    <title>节目B</title>
  </programme>
</tv>
''');
      // The trailing programme has no successor and is dropped.
      expect(feed.programmes, hasLength(1));
      final p = feed.programmes.single;
      expect(p.title, '节目A');
      expect(p.start, DateTime.utc(2026, 9, 21, 4));
      expect(p.stop, DateTime.utc(2026, 9, 21, 5));
    });

    test('keeps programmes with an explicit stop untouched', () {
      final feed = parser.parse('''
<tv>
  <programme channel="cctv1" start="20260921120000 +0800"
             stop="20260921124500 +0800">
    <title>节目A</title>
  </programme>
  <programme channel="cctv1" start="20260921130000 +0800">
    <title>节目B</title>
  </programme>
</tv>
''');
      // The trailing programme has no successor and is dropped.
      expect(feed.programmes, hasLength(1));
      expect(feed.programmes.single.stop, DateTime.utc(2026, 9, 21, 4, 45));
    });

    test('drops a borrowed stop that would make the programme zero-length', () {
      final feed = parser.parse('''
<tv>
  <programme channel="cctv1" start="20260921120000 +0800">
    <title>节目A</title>
  </programme>
  <programme channel="cctv1" start="20260921120000 +0800"
             stop="20260921130000 +0800">
    <title>节目B</title>
  </programme>
</tv>
''');
      // Overlapping schedules sharing a start time: the borrow would give
      // 节目A a zero length, so it is dropped instead.
      expect(feed.programmes, hasLength(1));
      expect(feed.programmes.single.title, '节目B');
    });
  });

  group('parseXmltvTime', () {
    test('parses timezone-less timestamps as UTC', () {
      expect(
        XmltvParser.parseXmltvTime('20260921120000'),
        DateTime.utc(2026, 9, 21, 12),
      );
    });

    test('parses negative offsets', () {
      expect(
        XmltvParser.parseXmltvTime('20260921120000 -0500'),
        DateTime.utc(2026, 9, 21, 17),
      );
    });

    test('accepts colon-separated timezone offsets', () {
      expect(
        XmltvParser.parseXmltvTime('20260921120000 +08:00'),
        DateTime.utc(2026, 9, 21, 4),
      );
      expect(
        XmltvParser.parseXmltvTime('20260921120000 -05:00'),
        DateTime.utc(2026, 9, 21, 17),
      );
    });

    test('rejects overflowing dates, offsets and trailing garbage', () {
      for (final value in [
        '20260230120000',
        '20260921250000',
        '20260921120000 +0860',
        '20260921120000 +9900',
        '20260921120000 junk',
      ]) {
        expect(XmltvParser.parseXmltvTime(value), isNull);
      }
    });

    test('returns null for malformed input', () {
      expect(XmltvParser.parseXmltvTime('nope'), isNull);
      expect(XmltvParser.parseXmltvTime(null), isNull);
    });
  });
}
