import 'package:iptv_core/src/entities/probe_result.dart';

/// Port for stream availability probing strategies
/// (HTTP HEAD, ranged GET, deep stream probe, ...).
abstract interface class StreamProber {
  /// Probes [url] and classifies the outcome. Implementations never throw;
  /// failures are encoded in the returned [ProbeResult].
  Future<ProbeResult> probe(String url, {Duration timeout});
}
