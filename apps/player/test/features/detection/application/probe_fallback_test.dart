import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';

import '../../../helpers/fake_probe_result_repository.dart';

void main() {
  for (final failedStatus in [ProbeStatus.dead, ProbeStatus.timeout]) {
    for (final reversed in [false, true]) {
      test(
        'unsupported fallback survives $failedStatus, reversed=$reversed',
        () async {
          const sources = [
            Channel(name: 'News', streamUrl: 'http://example.com/live'),
            Channel(name: 'News', streamUrl: 'udp://239.0.0.1:1234'),
          ];
          final repository = FakeProbeResultRepository();
          final run = RunAvailabilityProbe(
            prober: _Prober(failedStatus),
            results: repository,
            concurrency: 1,
          );

          final snapshots = await run(
            reversed ? sources.reversed.toList() : sources,
          ).toList();

          expect(snapshots.last.results['news']!.isAvailable, isTrue);
          expect(
            (await repository.watchAll().first)['news']!.status,
            ProbeStatus.unsupported,
          );
        },
      );
    }
  }
}

class _Prober implements StreamProber {
  _Prober(this.failedStatus);

  final ProbeStatus failedStatus;

  @override
  Future<ProbeResult> probe(
    String url, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final unsupported = url.startsWith('udp:');
    return ProbeResult(
      url: url,
      status: unsupported ? ProbeStatus.unsupported : failedStatus,
      checkedAt: DateTime.now(),
      latency: unsupported ? null : const Duration(milliseconds: 20),
    );
  }
}
