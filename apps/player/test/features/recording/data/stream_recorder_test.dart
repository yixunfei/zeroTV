import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotv_player/features/recording/data/stream_recorder.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late StreamRecorder recorder;
  late String path;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    directory = await Directory.systemTemp.createTemp('zerotv_capture_');
    path = '${directory.path}/capture.ts';
    recorder = StreamRecorder();
    server.listen((request) async {
      if (request.uri.path == '/missing') {
        request.response.statusCode = 404;
      } else if (request.uri.path == '/playlist') {
        request.response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        request.response.write('#EXTM3U\nsegment.ts');
      } else {
        request.response.headers.contentType = ContentType('video', 'mp2t');
        request.response.add([1, 2, 3, 4]);
        if (request.uri.path == '/live') {
          await request.response.flush();
          return;
        }
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    recorder.close();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Uri url(String suffix) =>
      Uri.parse('http://127.0.0.1:${server.port}/$suffix');

  test('EOF closes the file and repeated stop remains safe', () async {
    final handle = await recorder.start(url: url('media'), filePath: path);
    await handle.done;
    await Future.wait([handle.stop(), handle.stop()]);
    expect(handle.isActive, isFalse);
    expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
  });

  test('simultaneous stop on a live response shares file cleanup', () async {
    final handle = await recorder.start(url: url('live'), filePath: path);
    await Future.wait([handle.stop(), handle.stop()]);
    await handle.done;
    expect(handle.isActive, isFalse);
  });

  test('HTTP errors and playlists do not produce fake video files', () async {
    for (final endpoint in ['missing', 'playlist', 'stream.m3u8']) {
      await expectLater(
        recorder.start(url: url(endpoint), filePath: path),
        throwsA(isA<Object>()),
      );
      expect(File(path).existsSync(), isFalse);
    }
  });

  test(
    'disk errors complete the capture instead of escaping unhandled',
    () async {
      final handle = await recorder.start(
        url: url('media'),
        filePath: directory.path,
      );
      await expectLater(handle.done, throwsA(isA<FileSystemException>()));
      expect(handle.isActive, isFalse);
    },
  );
}
