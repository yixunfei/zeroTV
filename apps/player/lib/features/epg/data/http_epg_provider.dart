import 'dart:io';

import 'package:dio/dio.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:xmltv_parser/xmltv_parser.dart';
import 'package:zerotv_player/core/text/content_encoding.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

/// Fetches XMLTV feeds over HTTP(S), transparently gunzipping `.gz` bodies.
///
/// Some hosts send `Content-Encoding: gzip` (handled by dio); others serve
/// a raw `.xml.gz` file with no content-encoding, which is decompressed here.
class HttpEpgProvider implements EpgProvider {
  /// Creates the provider.
  HttpEpgProvider({
    required Dio dio,
    this.parser = const XmltvParser(),
    this.timeout = const Duration(seconds: 30),
  }) : _dio = dio;

  final Dio _dio;

  /// The XMLTV parser.
  final XmltvParser parser;

  /// Per-request receive timeout.
  final Duration timeout;

  @override
  Future<EpgFeed> fetch(Uri uri) async {
    try {
      final res = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: timeout,
        ),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw SubscriptionFetchException('EPG 响应为空：$uri');
      }
      final content = _decode(bytes);
      return parser.parse(content);
    } on DioException catch (e) {
      throw SubscriptionFetchException('EPG 拉取失败：$e');
    } on FormatException catch (e) {
      throw SubscriptionFetchException('EPG 解析失败：$e');
    }
  }

  String _decode(List<int> bytes) {
    final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    final decoded = isGzip ? gzip.decode(bytes) : bytes;
    // Honor the prolog's encoding declaration (GBK feeds declare
    // themselves there) instead of blindly decoding as UTF-8.
    return decodeTextContent(
      decoded,
      declaredEncoding: xmlDeclaredEncoding(decoded),
    );
  }
}
