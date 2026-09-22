import 'dart:convert';

import 'package:iptv_core/iptv_core.dart';

/// Parses M3U/M3U8 playlists into [ParsedPlaylist].
///
/// Supported syntax:
/// - `#EXTM3U` header with `x-tvg-url` EPG pointer
/// - `#EXTINF` with quoted attributes (`tvg-id`, `tvg-name`, `tvg-logo`,
///   `group-title`, `catchup`, `catchup-source`, `catchup-days`) and the
///   channel name after the last comma
/// - `#EXTVLCOPT:http-user-agent` / `http-referrer` applying to the next
///   entry
/// - bare URL lines without `#EXTINF` (named from the URL path)
///
/// Malformed entries are skipped; parsing never throws.
class M3uPlaylistParser implements PlaylistParser {
  /// Creates a parser.
  const M3uPlaylistParser();

  static final RegExp _attribute = RegExp(r'([\w-]+)="([^"]*)"');

  @override
  ParsedPlaylist parse(RawPlaylist raw) {
    final channels = <Channel>[];
    Uri? epgUrl;
    final pending = _PendingEntry();

    for (final rawLine in const LineSplitter().convert(raw.content)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      } else if (line.startsWith('#EXTM3U')) {
        epgUrl ??= _epgUrlFrom(line);
      } else if (line.startsWith('#EXTINF:')) {
        pending
          ..reset()
          ..attrs.addAll(_attributesOf(line))
          ..name = _nameOf(line);
      } else if (line.startsWith('#EXTVLCOPT:')) {
        pending.applyVlcOpt(line);
      } else if (!line.startsWith('#')) {
        channels.add(pending.toChannel(line));
        pending.reset();
      }
    }
    return ParsedPlaylist(channels: channels, epgUrl: epgUrl);
  }

  Map<String, String> _attributesOf(String line) {
    final attrs = <String, String>{};
    for (final m in _attribute.allMatches(line)) {
      attrs[m.group(1)!] = m.group(2)!;
    }
    return attrs;
  }

  Uri? _epgUrlFrom(String headerLine) {
    final value = _attributesOf(headerLine)['x-tvg-url'];
    if (value == null || value.isEmpty) return null;
    // Some playlists list several comma-separated EPG URLs; take the first.
    return Uri.tryParse(value.split(',').first.trim());
  }

  String _nameOf(String extinfLine) {
    final comma = extinfLine.lastIndexOf(',');
    if (comma < 0 || comma == extinfLine.length - 1) return '未命名频道';
    return extinfLine.substring(comma + 1).trim();
  }
}

/// Mutable accumulator for the entry currently being read.
class _PendingEntry {
  String? name;
  String? userAgent;
  String? referrer;
  final Map<String, String> attrs = {};

  void reset() {
    name = null;
    userAgent = null;
    referrer = null;
    attrs.clear();
  }

  void applyVlcOpt(String line) {
    final body = line.substring('#EXTVLCOPT:'.length);
    final eq = body.indexOf('=');
    if (eq <= 0) return;
    final key = body.substring(0, eq).trim();
    final value = body.substring(eq + 1).trim();
    switch (key) {
      case 'http-user-agent':
        userAgent = value;
      case 'http-referrer':
        referrer = value;
    }
  }

  Channel toChannel(String url) {
    return Channel(
      name: name ?? _fallbackName(url),
      streamUrl: url,
      tvgId: attrs['tvg-id'],
      tvgName: attrs['tvg-name'],
      logoUrl: attrs['tvg-logo'],
      groupTitle: attrs['group-title'],
      catchupSource: attrs['catchup-source'] ?? attrs['catchup'],
      catchupDays: int.tryParse(attrs['catchup-days'] ?? ''),
      userAgent: userAgent,
      referrer: referrer,
    );
  }

  String _fallbackName(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return url;
    final last = uri.pathSegments.last;
    return last.isEmpty ? url : last;
  }
}
