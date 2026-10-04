/// Text decoding for downloaded playlist/EPG bodies.
///
/// Chinese IPTV sources are frequently GBK-encoded and rarely declare a
/// charset; XMLTV feeds declare theirs in the `<?xml?>` prolog. Decoding
/// blindly as UTF-8 turns those bodies into replacement-character soup.
/// [decodeTextContent] sniffs BOMs, honors an explicitly declared
/// encoding, and otherwise falls back from strict UTF-8 to GBK.
library;

import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';

const _gbkAliases = {'gbk', 'gb2312', 'gb18030'};

/// Decodes [bytes] into text.
///
/// [declaredEncoding] optionally passes a charset name found in a
/// transport header or document prolog (e.g. XML's `encoding="GBK"`).
/// Unknown names fall back to the sniffing order below, so a bogus
/// declaration cannot make decoding fail outright.
///
/// Order: BOM (UTF-8/UTF-16) > declared encoding > strict UTF-8 > GBK.
String decodeTextContent(List<int> bytes, {String? declaredEncoding}) {
  // BOM sniffing.
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }

  final declared = declaredEncoding?.trim().toLowerCase();
  if (declared != null) {
    // Honor an explicit declaration when we support it.
    if (_gbkAliases.contains(declared)) return gbk_bytes.decode(bytes);
    if (declared == 'utf-8' || declared == 'utf8' || declared == 'us-ascii') {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  // Strict UTF-8 first: valid UTF-8 must never be misread as GBK.
  try {
    return utf8.decode(bytes);
  } on FormatException {
    // Not valid UTF-8 — assume GBK (the dominant legacy charset for
    // IPTV lists). Its decoder never throws; undecodable pairs pass
    // through as lone code points.
    return gbk_bytes.decode(bytes);
  }
}

/// Extracts the encoding name from an `<?xml ... ?>` prolog, if any.
///
/// The prolog is ASCII regardless of the document encoding, so a
/// permissive single-byte decode of the leading bytes is enough.
String? xmlDeclaredEncoding(List<int> bytes) {
  final prolog = latin1.decode(bytes.take(512).toList());
  final match = RegExp(
    '<\\?xml[^>]*?encoding\\s*=\\s*["\']([A-Za-z0-9._-]+)["\']',
  ).firstMatch(prolog);
  return match?.group(1);
}

String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
  final codeUnits = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    codeUnits.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(codeUnits);
}
