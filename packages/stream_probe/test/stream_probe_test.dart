import 'dart:async';
import 'dart:io';

import 'package:iptv_core/iptv_core.dart';
import 'package:stream_probe/stream_probe.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late String base;
  late HttpStreamProber prober;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    prober = HttpStreamProber();
    server.listen((request) {
      switch (request.uri.path) {
        case '/ok':
          request.response.statusCode = HttpStatus.ok;
        case '/notfound':
          request.response.statusCode = HttpStatus.notFound;
        case '/slow':
          unawaited(
            Future<void>.delayed(const Duration(seconds: 3), () {
              request.response.statusCode = HttpStatus.ok;
              unawaited(request.response.close());
            }),
          );
          return;
      }
      unawaited(request.response.close());
    });
  });

  tearDown(() async {
    prober.close();
    await server.close(force: true);
  });

  group('HttpStreamProber', () {
    test('reports ok with latency for a reachable endpoint', () async {
      final r = await prober.probe('$base/ok');
      expect(r.status, ProbeStatus.ok);
      expect(r.latency, isNotNull);
      expect(r.httpStatus, HttpStatus.ok);
    });

    test('reports dead for 404', () async {
      final r = await prober.probe('$base/notfound');
      expect(r.status, ProbeStatus.dead);
      expect(r.httpStatus, HttpStatus.notFound);
    });

    test('reports dead for a closed port', () async {
      final r = await prober.probe('http://127.0.0.1:1/x');
      expect(r.status, ProbeStatus.dead);
    });

    test('reports timeout for a slow endpoint', () async {
      final r = await prober.probe(
        '$base/slow',
        timeout: const Duration(milliseconds: 300),
      );
      expect(r.status, ProbeStatus.timeout);
    });

    test('reports unsupported for the udp scheme', () async {
      final r = await prober.probe('udp://239.0.0.1:1234');
      expect(r.status, ProbeStatus.unsupported);
    });
  });

  group('ProbePool', () {
    test('probes all urls and emits one result per url', () async {
      final pool = ProbePool(prober: prober, concurrency: 2);
      final results = await pool.probeAll([
        '$base/ok',
        '$base/notfound',
        'udp://239.0.0.1:1',
      ]).toList();
      expect(results, hasLength(3));
      expect(
        results.map((r) => r.status).toSet(),
        {ProbeStatus.ok, ProbeStatus.dead, ProbeStatus.unsupported},
      );
    });

    test('handles an empty url list', () async {
      final pool = ProbePool(prober: prober);
      expect(await pool.probeAll(const []).toList(), isEmpty);
    });
  });
}
