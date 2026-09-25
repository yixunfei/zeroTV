/// Frame-time statistics helpers shared by perf tests.
library;

import 'package:flutter/scheduler.dart';

/// Aggregated frame-time stats. All durations are reported as
/// milliseconds of *total* frame time (build + raster), which is what
/// the 16.67ms 60fps budget applies to.
class PerfStats {
  const PerfStats._({
    required this.sampleCount,
    required this.averageMs,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.jankFrames,
  });

  /// Builds stats from raw [FrameTiming] samples.
  factory PerfStats.fromTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) {
      return const PerfStats._(
        sampleCount: 0,
        averageMs: 0,
        p95Ms: 0,
        p99Ms: 0,
        maxMs: 0,
        jankFrames: 0,
      );
    }
    final durations =
        timings.map((t) => t.totalSpan.inMicroseconds / 1000.0).toList()
          ..sort();
    var sum = 0.0;
    var max = 0.0;
    var jank = 0;
    for (final d in durations) {
      sum += d;
      if (d > max) max = d;
      if (d > frameBudgetMs) jank++;
    }
    double percentile(double p) {
      if (durations.isEmpty) return 0;
      final idx = ((durations.length - 1) * p).round();
      return durations[idx];
    }

    return PerfStats._(
      sampleCount: durations.length,
      averageMs: sum / durations.length,
      p95Ms: percentile(0.95),
      p99Ms: percentile(0.99),
      maxMs: max,
      jankFrames: jank,
    );
  }

  /// Number of frames sampled.
  final int sampleCount;

  /// Mean frame time in ms.
  final double averageMs;

  /// 95th percentile frame time in ms.
  final double p95Ms;

  /// 99th percentile frame time in ms.
  final double p99Ms;

  /// Slowest observed frame in ms.
  final double maxMs;

  /// Number of frames that exceeded the 60fps budget (16.67ms).
  final int jankFrames;

  /// [jankFrames] as a fraction of [sampleCount]; 0 when no samples.
  double get jankRatio => sampleCount == 0 ? 0 : jankFrames / sampleCount;

  /// Budget in ms for one frame at 60fps.
  static const double frameBudgetMs = 16.67;
}
