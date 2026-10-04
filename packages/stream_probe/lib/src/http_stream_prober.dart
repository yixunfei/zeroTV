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
  /// Creates a prober. [client] is injectable for testing; an injected
  /// client stays owned by the caller and is not closed by [close].
  HttpStreamProber({HttpClient? client})
    : _client = client ?? HttpClient(),
      _ownsClient = client == null {
    if (_ownsClient) {
      _client
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 15)
        ..maxConnectionsPerHost = 8;
    }
  }

  final HttpClient _client;
  final bool _ownsClient;

  /// Releases the underlying [HttpClient] if this prober created it.
  void close() {
    if (_ownsClient) _client.close(force: true);
  }

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
      final status = await (() async {
        final head = await _request(uri, 'HEAD', timeout);
        if (head == HttpStatus.methodNotAllowed ||
            head == HttpStatus.forbidden ||
            head == HttpStatus.notImplemented) {
          return _request(uri, 'GET', timeout - sw.elapsed);
        }
        return head;
      })();
      sw.stop();
      // Redirects are followed automatically; a final 3xx means the
      // redirect limit was hit or redirects were disabled, i.e. the
      // stream itself never answered.
      final ok = status >= 200 && status < 300;
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

  Future<int> _request(Uri uri, String method, Duration timeout) async {
    HttpClientRequest? request;
    var expired = false;
    try {
      return await (() async {
        final opened = await _client.openUrl(method, uri);
        request = opened;
        if (expired) {
          opened.abort();
          throw TimeoutException('probe deadline expired');
        }
        if (method == 'GET') {
          opened.headers.set(HttpHeaders.rangeHeader, 'bytes=0-511');
        }
        final response = await opened.close();
        // Live servers may ignore Range and never close the response.
        // Headers are sufficient for this shallow availability probe.
        await response.listen((_) {}).cancel();
        return response.statusCode;
      })().timeout(timeout);
    } finally {
      expired = true;
      request?.abort();
    }
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
