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
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2}):?(\d{2}))?$',
  );

  /// Parses [xmlContent] into an [EpgFeed].
  ///
  /// Malformed entries are skipped. A `programme` without a `stop`
  /// attribute (optional per the XMLTV DTD) borrows the start time of the
  /// next programme on the same channel; it is only skipped when no
  /// following programme exists.
  ///
  /// Throws [XmlException] when the document itself is not well-formed
  /// XML, or [FormatException] when the root element is not `<tv>`.
  EpgFeed parse(String xmlContent) {
    final root = XmlDocument.parse(xmlContent).rootElement;
    if (root.name.local != 'tv') {
      throw const FormatException('Expected an XMLTV <tv> document');
    }
    final drafts = [
      for (final el in root.findElements('programme')) ?_toDraft(el),
    ];
    _fillMissingStops(drafts);
    return EpgFeed(
      channels: [
        for (final el in root.findElements('channel')) ?_toChannel(el),
      ],
      programmes: [
        for (final d in drafts)
          if (d.stop != null) d.toProgram(),
      ],
    );
  }

  /// Fills a missing `stop` with the next programme's start on the same
  /// channel. The trailing programme of each channel keeps a null stop and
  /// is dropped by the caller.
  static void _fillMissingStops(List<_ProgramDraft> drafts) {
    final byChannel = <String, List<_ProgramDraft>>{};
    for (final d in drafts) {
      byChannel.putIfAbsent(d.channelId, () => []).add(d);
    }
    for (final group in byChannel.values) {
      group.sort((a, b) => a.start.compareTo(b.start));
      for (var i = 0; i + 1 < group.length; i++) {
        final next = group[i + 1].start;
        // A zero-length borrow (overlapping schedules sharing a start time)
        // is invalid; keep the stop null so the entry is dropped, matching
        // the explicit-stop validation in _toDraft.
        if (next.isAfter(group[i].start)) group[i].stop ??= next;
      }
    }
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

  _ProgramDraft? _toDraft(XmlElement el) {
    final channelId = el.getAttribute('channel');
    final start = parseXmltvTime(el.getAttribute('start'));
    final stop = parseXmltvTime(el.getAttribute('stop'));
    final title = _firstOrNull(el.findElements('title'))?.innerText;
    if (channelId == null ||
        channelId.isEmpty ||
        start == null ||
        title == null) {
      return null;
    }
    if (stop != null && !stop.isAfter(start)) return null;
    return _ProgramDraft(
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
    final parts = [
      assumedUtc.year,
      assumedUtc.month,
      assumedUtc.day,
      assumedUtc.hour,
      assumedUtc.minute,
      assumedUtc.second,
    ];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != int.parse(m.group(i + 1)!)) return null;
    }
    final sign = m.group(7);
    if (sign == null) return assumedUtc;
    if (int.parse(m.group(8)!) > 23 || int.parse(m.group(9)!) > 59) {
      return null;
    }
    final offset = Duration(
      hours: int.parse(m.group(8)!),
      minutes: int.parse(m.group(9)!),
    );
    return sign == '+' ? assumedUtc.subtract(offset) : assumedUtc.add(offset);
  }

  static T? _firstOrNull<T>(Iterable<T> it) => it.isEmpty ? null : it.first;
}

/// Mutable programme accumulator whose [stop] may be filled in a second
/// pass (see [XmltvParser._fillMissingStops]).
class _ProgramDraft {
  _ProgramDraft({
    required this.channelId,
    required this.title,
    required this.start,
    this.stop,
    this.description,
  });

  final String channelId;
  final String title;
  final DateTime start;
  DateTime? stop;
  final String? description;

  EpgProgram toProgram() => EpgProgram(
    channelId: channelId,
    title: title,
    start: start,
    stop: stop!,
    description: description,
  );
}
