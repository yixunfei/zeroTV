import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:zerotv_player/core/text/content_encoding.dart';

void main() {
  test('decodes plain UTF-8', () {
    expect(decodeTextContent(utf8.encode('#EXTM3U 中央')), '#EXTM3U 中央');
  });

  test('decodes GBK bodies without a declaration', () {
    final gbk = gbk_bytes.encode('#EXTM3U 中央电视台');
    expect(decodeTextContent(gbk), '#EXTM3U 中央电视台');
  });

  test('honors a GBK declaration even when the bytes are ASCII-only', () {
    // Pure ASCII is valid UTF-8 too; the declaration must win.
    const xml = '<?xml version="1.0" encoding="GBK"?><tv>中文</tv>';
    final bytes = gbk_bytes.encode(xml);
    expect(
      decodeTextContent(bytes, declaredEncoding: xmlDeclaredEncoding(bytes)),
      xml,
    );
  });

  test('extracts the encoding from an XML prolog', () {
    expect(
      xmlDeclaredEncoding(
        utf8.encode('<?xml version="1.0" encoding="gb2312"?>'),
      ),
      'gb2312',
    );
    expect(xmlDeclaredEncoding(utf8.encode('<?xml version="1.0"?>')), isNull);
    expect(xmlDeclaredEncoding(const []), isNull);
  });

  test('strips a UTF-8 BOM', () {
    final bytes = [0xef, 0xbb, 0xbf, ...utf8.encode('你好')];
    expect(decodeTextContent(bytes), '你好');
  });

  test('decodes UTF-16 LE with BOM', () {
    const text = '新闻联播';
    final units = text.codeUnits;
    final bytes = <int>[
      0xff,
      0xfe,
      for (final u in units) ...[u & 0xff, u >> 8],
    ];
    expect(decodeTextContent(bytes), text);
  });

  test('unknown declared encodings fall back to sniffing', () {
    expect(
      decodeTextContent(
        utf8.encode('#EXTM3U'),
        declaredEncoding: 'not-a-charset',
      ),
      '#EXTM3U',
    );
  });
}
