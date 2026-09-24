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
    final urlToKey = <String, String>{};
    final urls = <String>[];
    for (final c in channels) {
      urlToKey[c.streamUrl] = c.identityKey;
      urls.add(c.streamUrl);
    }
    final results = <String, ProbeResult>{};
    yield ProbeProgress(total: urls.length, completed: 0, results: results);
    await for (final result in _pool.probeAll(urls, timeout: timeout)) {
      final key = urlToKey[result.url];
      if (key == null) continue;
      results[key] = result;
      await _results.save(key, result);
      yield ProbeProgress(
        total: urls.length,
        completed: results.length,
        results: Map.unmodifiable(results),
      );
    }
  }
}
