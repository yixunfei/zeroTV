import 'package:iptv_core/iptv_core.dart';
import 'package:stream_probe/stream_probe.dart';

/// Progress snapshot of a batch availability scan.
class ProbeProgress {
  /// Creates a progress snapshot.
  const ProbeProgress({
    required this.total,
    required this.completed,
    required this.results,
  });

  /// Number of channels to probe.
  final int total;

  /// Number of channels probed so far.
  final int completed;

  /// Results collected so far, keyed by channel identity key.
  final Map<String, ProbeResult> results;

  /// Whether the scan has finished.
  bool get isDone => completed >= total;
}

/// Runs a [ProbePool] over a list of channels, persisting each result
/// as it arrives, and reports progress through a stream.
class RunAvailabilityProbe {
  /// Creates the use case.
  RunAvailabilityProbe({
    required StreamProber prober,
    required ProbeResultRepository results,
    int concurrency = 16,
  }) : _pool = ProbePool(prober: prober, concurrency: concurrency),
       _results = results;

  final ProbePool _pool;
  final ProbeResultRepository _results;

  /// Probes [channels] concurrently, emitting progress as results land.
  ///
  /// [timeout] is the per-stream timeout; results are persisted in
  /// completion order, so partial progress survives a cancelled scan.
  Stream<ProbeProgress> call(
    List<Channel> channels, {
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    final urlToKeys = <String, List<String>>{};
    for (final c in channels) {
      urlToKeys.putIfAbsent(c.streamUrl, () => []).add(c.identityKey);
    }
    final urls = urlToKeys.keys.toList();
    final results = <String, ProbeResult>{};
    var completed = 0;
    yield ProbeProgress(
      total: channels.length,
      completed: 0,
      results: const {},
    );
    await for (final result in _pool.probeAll(urls, timeout: timeout)) {
      final keys = urlToKeys[result.url];
      if (keys == null) continue;
      completed += keys.length;
      for (final key in keys.toSet()) {
        // A channel identity can have several source URLs. Keep the best
        // result so failover resolution naturally prefers an available,
        // low-latency endpoint even when probes finish out of order.
        final previous = results[key];
        if (_isBetter(result, previous)) {
          results[key] = result;
          await _results.save(key, result);
        }
      }
      yield ProbeProgress(
        total: channels.length,
        completed: completed,
        results: Map.unmodifiable(results),
      );
    }
  }

  bool _isBetter(ProbeResult candidate, ProbeResult? previous) {
    if (previous == null) return true;
    if (candidate.status == ProbeStatus.ok &&
        previous.status != ProbeStatus.ok) {
      return true;
    }
    if (candidate.status != ProbeStatus.ok &&
        previous.status == ProbeStatus.ok) {
      return false;
    }
    final candidateLatency = candidate.latency;
    final previousLatency = previous.latency;
    if (candidateLatency != null && previousLatency == null) return true;
    if (candidateLatency == null || previousLatency == null) return false;
    return candidateLatency < previousLatency;
  }
}
