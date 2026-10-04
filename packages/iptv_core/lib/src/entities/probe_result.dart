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

  /// Measured round-trip latency, when a response or timeout was
  /// observed. Null for early failures (e.g. unsupported scheme).
  final Duration? latency;

  /// HTTP status code when the endpoint answered over HTTP.
  final int? httpStatus;

  /// Diagnostic message for failures.
  final String? error;

  /// Whether the endpoint should be included in the user's available view.
  ///
  /// Non-HTTP streams cannot be verified by the HTTP probe, but media_kit
  /// can still play them. Treating them as available keeps UDP/RTSP channels
  /// from disappearing from the default view merely because the probe has no
  /// HTTP strategy for them.
  bool get isAvailable =>
      status == ProbeStatus.ok || status == ProbeStatus.unsupported;

  /// How long a probe result stays trustworthy.
  ///
  /// Live stream endpoints churn constantly; results older than this are
  /// treated as expired (unknown) by the UI and failover resolution.
  static const Duration stalenessThreshold = Duration(hours: 24);

  /// Whether this result is older than [maxAge] relative to [now].
  bool isStale({DateTime? now, Duration maxAge = stalenessThreshold}) {
    final reference = now ?? DateTime.now();
    return reference.difference(checkedAt) >= maxAge;
  }
}
