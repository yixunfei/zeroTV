import 'package:iptv_core/iptv_core.dart';
import 'package:xml/xml.dart';

/// Parses XMLTV documents into [EpgFeed].
///
/// Current scope: whole-document parsing, suitable for small/medium feeds.
/// Large feeds (tens of MB) will move to streaming, isolate-based parsing
/// with gzip support in a later milestone; the public API stays unchanged.
class XmltvParser {
  /// Creates a parser.
  const XmltvParser();

  static final RegExp _timePattern = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?',
  );

  /// Parses [xmlContent] into an [EpgFeed].
  ///
  /// Malformed entries are skipped. Throws [XmlException] when the document
  /// itself is not well-formed XML.
  EpgFeed parse(String xmlContent) {
    final root = XmlDocument.parse(xmlContent).rootElement;
    return EpgFeed(
      channels: [
        for (final el in root.findElements('channel')) ?_toChannel(el),
      ],
      programmes: [
        for (final el in root.findElements('programme')) ?_toProgram(el),
      ],
    );
  }

  EpgChannel? _toChannel(XmlElement el) {
    final id = el.getAttribute('id');
    if (id == null || id.isEmpty) return null;
    return EpgChannel(
      id: id,
      displayName:
          _firstOrNull(el.findElements('display-name'))?.innerText ?? id,
      iconUrl: _firstOrNull(el.findElements('icon'))?.getAttribute('src'),
    );
  }

  EpgProgram? _toProgram(XmlElement el) {
    final channelId = el.getAttribute('channel');
    final start = parseXmltvTime(el.getAttribute('start'));
    final stop = parseXmltvTime(el.getAttribute('stop'));
    final title = _firstOrNull(el.findElements('title'))?.innerText;
    if (channelId == null || start == null || stop == null || title == null) {
      return null;
    }
    return EpgProgram(
      channelId: channelId,
      title: title,
      start: start,
      stop: stop,
      description: _firstOrNull(el.findElements('desc'))?.innerText,
    );
  }

  /// Parses XMLTV timestamps like `20260921120000 +0800` into UTC.
  ///
  /// A missing timezone means UTC. Returns null for malformed input.
  static DateTime? parseXmltvTime(String? raw) {
    if (raw == null) return null;
    final m = _timePattern.firstMatch(raw.trim());
    if (m == null) return null;
    final assumedUtc = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
    final sign = m.group(7);
    if (sign == null) return assumedUtc;
    final offset = Duration(
      hours: int.parse(m.group(8)!),
      minutes: int.parse(m.group(9)!),
    );
    return sign == '+' ? assumedUtc.subtract(offset) : assumedUtc.add(offset);
  }

  static T? _firstOrNull<T>(Iterable<T> it) => it.isEmpty ? null : it.first;
}
