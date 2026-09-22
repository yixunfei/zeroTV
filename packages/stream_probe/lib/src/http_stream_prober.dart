import 'dart:async';
import 'dart:io';

import 'package:iptv_core/iptv_core.dart';

/// Probes HTTP(S) stream endpoints with HEAD, falling back to a ranged GET.
///
/// Non-HTTP schemes (`udp://`, `rtsp://`, ...) cannot be probed over HTTP
/// and are reported as [ProbeStatus.unsupported].
///
/// Note: a 200 on an `.m3u8` playlist does not guarantee that its segments
/// are reachable. A deep probe (fetching and validating the playlist body)
/// is a planned strategy, not part of this implementation.
class HttpStreamProber implements StreamProber {
  /// Creates a prober. [client] is injectable for testing.
  HttpStreamProber({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// Releases the underlying [HttpClient].
  void close() => _client.close();

  @override
  Future<ProbeResult> probe(
    String url, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('HTTP') || uri.isScheme('HTTPS'))) {
      return _result(url, ProbeStatus.unsupported, error: 'unsupported scheme');
    }
    final sw = Stopwatch()..start();
    try {
      final status =
          await _head(uri, timeout) ?? await _rangedGet(uri, timeout);
      sw.stop();
      if (status == null) {
        return _result(url, ProbeStatus.dead, error: 'no response');
      }
      final ok = status >= 200 && status < 400;
      return _result(
        url,
        ok ? ProbeStatus.ok : ProbeStatus.dead,
        latency: sw.elapsed,
        httpStatus: status,
        error: ok ? null : 'http $status',
      );
    } on TimeoutException {
      return _result(url, ProbeStatus.timeout, latency: sw.elapsed);
    } on Object catch (e) {
      return _result(url, ProbeStatus.dead, error: '$e');
    }
  }

  /// Returns the status code, or null when HEAD is not honoured and a
  /// ranged GET should be attempted.
  Future<int?> _head(Uri uri, Duration timeout) async {
    try {
      final request = await _client.headUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      // Many IPTV servers reject HEAD but serve GET fine.
      if (response.statusCode == HttpStatus.methodNotAllowed ||
          response.statusCode == HttpStatus.forbidden) {
        return null;
      }
      return response.statusCode;
    } on HttpException {
      return null;
    }
  }

  Future<int?> _rangedGet(Uri uri, Duration timeout) async {
    final request = await _client.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-511');
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    return response.statusCode;
  }

  ProbeResult _result(
    String url,
    ProbeStatus status, {
    Duration? latency,
    int? httpStatus,
    String? error,
  }) {
    return ProbeResult(
      url: url,
      status: status,
      checkedAt: DateTime.now(),
      latency: latency,
      httpStatus: httpStatus,
      error: error,
    );
  }
}
