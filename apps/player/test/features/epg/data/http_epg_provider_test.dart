import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:zerotv_player/features/epg/data/http_epg_provider.dart';

void main() {
  const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="cctv1"><display-name>CCTV-1</display-name></channel>
  <programme start="20260924120000 +0800" stop="20260924130000 +0800" channel="cctv1">
    <title>新闻联播</title>
  </programme>
</tv>''';

  test('parses a plain XMLTV body', () async {
    final provider = HttpEpgProvider(dio: _bytesDio(utf8.encode(xml)));

    final feed = await provider.fetch(Uri.parse('https://example.com/epg.xml'));

    expect(feed.channels.single.id, 'cctv1');
    expect(feed.programmes.single.title, '新闻联播');
  });

  test('gunzips a raw .gz body', () async {
    final gz = gzip.encode(utf8.encode(xml));
    final provider = HttpEpgProvider(dio: _bytesDio(gz));

    final feed = await provider.fetch(
      Uri.parse('https://example.com/epg.xml.gz'),
    );

    expect(feed.channels.single.displayName, 'CCTV-1');
    expect(feed.programmes.single.title, '新闻联播');
  });

  test(
    'does not decompress a gz URL already decoded by the HTTP client',
    () async {
      final provider = HttpEpgProvider(dio: _bytesDio(utf8.encode(xml)));
      final feed = await provider.fetch(
        Uri.parse('https://example.com/epg.xml.gz'),
      );
      expect(feed.programmes.single.title, '新闻联播');
    },
  );

  test('parses a GBK-encoded XMLTV body', () async {
    const gbkXml = '''
<?xml version="1.0" encoding="GBK"?>
<tv>
  <channel id="cctv1"><display-name>CCTV-1</display-name></channel>
  <programme start="20260924120000 +0800" stop="20260924130000 +0800" channel="cctv1">
    <title>新闻联播</title>
  </programme>
</tv>''';
    final provider = HttpEpgProvider(dio: _bytesDio(gbk_bytes.encode(gbkXml)));

    final feed = await provider.fetch(Uri.parse('https://example.com/epg.xml'));

    expect(feed.programmes.single.title, '新闻联播');
  });

  test('rejects non-XMLTV documents', () async {
    final provider = HttpEpgProvider(dio: _bytesDio(utf8.encode('<html/>')));
    await expectLater(
      provider.fetch(Uri.parse('https://example.com/epg')),
      throwsA(isA<Exception>()),
    );
  });

  test('throws when the body is empty', () async {
    final provider = HttpEpgProvider(dio: _bytesDio(const []));
    expect(
      () => provider.fetch(Uri.parse('https://example.com/epg.xml')),
      throwsA(isA<Object>()),
    );
  });
}

/// A [Dio] whose adapter returns [bytes] for any request.
Dio _bytesDio(List<int> bytes) {
  final dio = Dio()..httpClientAdapter = _StubAdapter(bytes);
  return dio;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.bytes);

  final List<int> bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}
