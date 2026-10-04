import 'dart:convert';

import 'package:iptv_core/iptv_core.dart';

/// Parses M3U/M3U8 playlists into [ParsedPlaylist].
///
/// Supported syntax:
/// - `#EXTM3U` header with `x-tvg-url` EPG pointer
/// - `#EXTINF` with quoted attributes (`tvg-id`, `tvg-name`, `tvg-logo`,
///   `group-title`, `catchup`, `catchup-source`, `catchup-days`) and the
///   channel name after the first unquoted comma
/// - `#EXTVLCOPT:http-user-agent` / `http-referrer` applying to the next
///   entry
/// - bare URL lines without `#EXTINF` (named from the URL path)
///
/// Malformed entries are skipped; parsing never throws.
class M3uPlaylistParser implements PlaylistParser {
  /// Creates a parser.
  const M3uPlaylistParser();

  static final RegExp _attribute = RegExp(r'([\w-]+)="([^"]*)"');
  static final RegExp _quotedSpan = RegExp('"[^"]*"');

  /// Unquoted attribute values (`tvg-id=CCTV1`): value runs to the next
  /// whitespace or comma.
  static final RegExp _unquotedAttribute = RegExp(r'([\w-]+)=([^"\s,]+)');
  static final RegExp _invalidUrlChars = RegExp(r'[\s<>]');

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
        epgUrl ??= _epgUrlFrom(line, raw.originUri);
      } else if (line.startsWith('#EXTINF:')) {
        // Only reset the per-entry fields. `#EXTVLCOPT` lines may precede
        // the `#EXTINF` they apply to and must survive this reset.
        pending
          ..resetEntry()
          // Attributes only live before the display name; `key=value` text
          // inside the name must not be picked up as attributes.
          ..attrs.addAll(_attributesOf(_attributePartOf(line)))
          ..name = _nameOf(line);
      } else if (line.startsWith('#EXTVLCOPT:')) {
        pending.applyVlcOpt(line);
      } else if (!line.startsWith('#')) {
        final url = _streamUrl(line, raw.originUri);
        if (url != null) channels.add(pending.toChannel(url));
        pending.resetAll();
      }
    }
    return ParsedPlaylist(channels: channels, epgUrl: epgUrl);
  }

  Map<String, String> _attributesOf(String line) {
    final attrs = <String, String>{};
    for (final m in _attribute.allMatches(line)) {
      attrs[m.group(1)!] = m.group(2)!;
    }
    // Some playlists leave the attribute values unquoted; quoted matches
    // (above) always win. Scan only outside quoted spans so `key=value`
    // text inside a quoted value cannot be mistaken for an attribute.
    for (final m in _unquotedAttribute.allMatches(
      line.replaceAll(_quotedSpan, ''),
    )) {
      attrs.putIfAbsent(m.group(1)!, () => m.group(2)!);
    }
    return attrs;
  }

  Uri? _epgUrlFrom(String headerLine, Uri? origin) {
    // Attribute variants used in the wild: `x-tvg-url`, `url-tvg`, `tvg-url`.
    final attrs = _attributesOf(headerLine);
    final value = (attrs['x-tvg-url'] ?? attrs['url-tvg'] ?? attrs['tvg-url'])
        ?.trim();
    if (value == null || value.isEmpty) return null;
    // Some playlists list several comma-separated EPG URLs; take the first.
    final uri = Uri.tryParse(value.split(',').first.trim());
    return uri == null ? null : origin?.resolveUri(uri) ?? uri;
  }

  String _nameOf(String extinfLine) {
    final comma = _unquotedCommaIndex(extinfLine);
    if (comma < 0 || comma == extinfLine.length - 1) return '未命名频道';
    return extinfLine.substring(comma + 1).trim();
  }

  /// The part of an `#EXTINF` line before the display name. Attributes only
  /// live in this prefix; `key=value` text inside the name (after the comma)
  /// must not be picked up as attributes.
  static String _attributePartOf(String extinfLine) {
    final comma = _unquotedCommaIndex(extinfLine);
    return comma < 0 ? extinfLine : extinfLine.substring(0, comma);
  }

  /// Index of the first comma outside quoted attribute values, or -1 when
  /// the line has none.
  static int _unquotedCommaIndex(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '"') quoted = !quoted;
      if (line[i] == ',' && !quoted) return i;
    }
    return -1;
  }

  String? _streamUrl(String line, Uri? origin) {
    var candidate = line;
    final raw = Uri.tryParse(candidate);
    if (raw == null) return null;
    if (raw.hasScheme) {
      // URLs may carry stray spaces (from hand-edited playlists); percent-
      // encode them instead of dropping the entry. `encodeFull` leaves
      // existing percent-escapes intact.
      if (candidate.contains(_invalidUrlChars)) {
        candidate = Uri.encodeFull(candidate);
      }
    } else if (candidate.contains(_invalidUrlChars)) {
      // A relative reference carrying whitespace or angle brackets is
      // prose/HTML error text ("Access denied.", "<p>503</p>"), not a
      // path; resolving it against the origin would fabricate channels.
      return null;
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    // Only resolve relative paths that belong to a playlist, not HTML/text.
    if (!uri.hasScheme &&
        !candidate.contains('/') &&
        !candidate.contains('.')) {
      return null;
    }
    final resolved = origin?.resolveUri(uri) ?? uri;
    if (!const {
      'http',
      'https',
      'rtsp',
      'rtmp',
      'udp',
      'rtp',
      'file',
    }.contains(resolved.scheme)) {
      return null;
    }
    if (resolved.scheme != 'file' && resolved.host.isEmpty) return null;
    return resolved.toString();
  }
}

/// Mutable accumulator for the entry currently being read.
class _PendingEntry {
  String? name;
  String? userAgent;
  String? referrer;
  final Map<String, String> attrs = {};

  /// Clears the per-entry fields (name/attrs) without touching the VLC
  /// options, which may precede the `#EXTINF` they apply to.
  void resetEntry() {
    name = null;
    attrs.clear();
  }

  /// Clears everything once the accumulated entry has been consumed.
  void resetAll() {
    resetEntry();
    userAgent = null;
    referrer = null;
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
      // `catchup` holds a mode name (default/append/...), not a URL
      // template; only `catchup-source` is a usable template.
      catchupSource: attrs['catchup-source'],
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
