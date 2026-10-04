import 'dart:async';
import 'dart:io';

import 'red_transport_stream.dart';

/// A red H.264 video served without Content-Length or HTTP Range support.
/// This exercises real video textures and non-seekable live input offline.
class LiveVideoFixture {
  LiveVideoFixture._(this._server) {
    _server.listen((request) => unawaited(_serve(request)));
  }

  final HttpServer _server;
  bool _closed = false;

  /// Starts an in-process server on the device under test.
  static Future<LiveVideoFixture> start() async {
    return LiveVideoFixture._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
  }

  /// Live endpoint with no seek support.
  String get url => 'http://127.0.0.1:${_server.port}/live.ts';

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType('video', 'mp2t');
    try {
      final video = redTransportStream();
      for (var offset = 0; offset < video.length && !_closed; offset += 1880) {
        final end = (offset + 1880).clamp(0, video.length);
        response.add(video.sublist(offset, end));
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // Keep the HTTP stream live until the test has inspected its texture.
      while (!_closed) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await response.close();
    } on IOException {
      // The player cancels its live connection during test teardown.
    }
  }

  /// Stops all test connections.
  Future<void> close() async {
    _closed = true;
    await _server.close(force: true);
  }
}
