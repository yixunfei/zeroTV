import 'dart:async';

import 'package:iptv_core/iptv_core.dart';

/// Runs a [StreamProber] over many URLs with bounded concurrency,
/// emitting each result as soon as it finishes.
class ProbePool {
  /// Creates a pool.
  ProbePool({required this.prober, this.concurrency = 16})
    : assert(concurrency > 0, 'concurrency must be positive');

  /// The probing strategy used for every URL.
  final StreamProber prober;

  /// Maximum number of concurrent probes.
  final int concurrency;

  /// Probes all [urls], yielding results in completion order.
  Stream<ProbeResult> probeAll(
    List<String> urls, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    var index = 0;
    var cancelled = false;
    late final StreamController<ProbeResult> controller;

    Future<void> worker() async {
      while (!cancelled && index < urls.length) {
        // Single-threaded event loop: read+increment is atomic here.
        final url = urls[index++];
        try {
          final result = await prober.probe(url, timeout: timeout);
          if (cancelled) return;
          controller.add(result);
        } on Object catch (error, stack) {
          if (!cancelled) controller.addError(error, stack);
        }
      }
    }

    final workerCount = concurrency < urls.length ? concurrency : urls.length;
    controller = StreamController<ProbeResult>(
      onListen: () => unawaited(
        Future.wait([
          for (var i = 0; i < workerCount; i++) worker(),
        ]).then((_) => controller.close()),
      ),
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }
}
