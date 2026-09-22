/// Outcome classification of a stream availability probe.
enum ProbeStatus {
  /// Stream responded and looks playable.
  ok,

  /// Probe exceeded the configured timeout.
  timeout,

  /// Endpoint is unreachable or refuses the connection.
  dead,

  /// Protocol cannot be probed over HTTP (e.g. `udp://`, `rtsp://`).
  unsupported,
}

/// Result of probing one stream URL for availability.
class ProbeResult {
  /// Creates a probe result.
  const ProbeResult({
    required this.url,
    required this.status,
    required this.checkedAt,
    this.latency,
    this.httpStatus,
    this.error,
  });

  /// The probed stream URL.
  final String url;

  /// Classified outcome.
  final ProbeStatus status;

  /// When the probe finished.
  final DateTime checkedAt;

  /// Round-trip latency when [status] is [ProbeStatus.ok].
  final Duration? latency;

  /// HTTP status code when the endpoint answered over HTTP.
  final int? httpStatus;

  /// Diagnostic message for failures.
  final String? error;
}
