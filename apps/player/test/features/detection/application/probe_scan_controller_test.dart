import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/detection/application/probe_scan_controller.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';

import '../../../helpers/fake_probe_result_repository.dart';

void main() {
  const channels = [
    Channel(name: 'A', streamUrl: 'http://a/1'),
    Channel(name: 'B', streamUrl: 'http://b/2'),
  ];

  ProviderContainer makeContainer(RunAvailabilityProbe probe) {
    final container = ProviderContainer(
      overrides: [runAvailabilityProbeProvider.overrideWithValue(probe)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'finished scan ends in ProbeScanDone with the available count',
    () async {
      final container = makeContainer(
        RunAvailabilityProbe(
          prober: _StubProber(const {
            'http://a/1': ProbeStatus.ok,
            'http://b/2': ProbeStatus.dead,
          }),
          results: FakeProbeResultRepository(),
        ),
      );

      await container.read(probeScanProvider.notifier).start(channels);

      final state = container.read(probeScanProvider);
      expect(state, isA<ProbeScanDone>());
      expect((state as ProbeScanDone).available, 1);
      expect(state.total, 2);
      expect(state.results, hasLength(2));
      expect(state.results['a']?.status, ProbeStatus.ok);
    },
  );

  test(
    'cancel switches to idle immediately and discards the outcome',
    () async {
      final gate = Completer<ProbeResult>();
      final container = makeContainer(
        RunAvailabilityProbe(
          prober: _GatedProber(gate),
          results: FakeProbeResultRepository(),
          concurrency: 1,
        ),
      );
      final notifier = container.read(probeScanProvider.notifier);

      final scan = notifier.start(channels);
      expect(container.read(probeScanProvider), isA<ProbeScanRunning>());

      notifier.cancel();
      expect(container.read(probeScanProvider), isA<ProbeScanIdle>());

      gate.complete(
        ProbeResult(
          url: 'http://a/1',
          status: ProbeStatus.ok,
          checkedAt: DateTime(2026, 9, 22, 8),
        ),
      );
      await scan;
      expect(container.read(probeScanProvider), isA<ProbeScanIdle>());
    },
  );

  test('start is ignored while a scan is already running', () async {
    final gate = Completer<ProbeResult>();
    final container = makeContainer(
      RunAvailabilityProbe(
        prober: _GatedProber(gate),
        results: FakeProbeResultRepository(),
        concurrency: 1,
      ),
    );
    final notifier = container.read(probeScanProvider.notifier);

    final first = notifier.start(channels);
    await notifier.start(channels); // must return instantly, no-op

    expect(container.read(probeScanProvider), isA<ProbeScanRunning>());
    notifier.cancel();
    gate.complete(
      ProbeResult(
        url: 'http://a/1',
        status: ProbeStatus.ok,
        checkedAt: DateTime(2026, 9, 22, 8),
      ),
    );
    await first;
  });
}

class _StubProber implements StreamProber {
  _StubProber(this._statuses);

  final Map<String, ProbeStatus> _statuses;

  @override
  Future<ProbeResult> probe(
    String url, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return ProbeResult(
      url: url,
      status: _statuses[url] ?? ProbeStatus.dead,
      checkedAt: DateTime(2026, 9, 22, 8),
    );
  }
}

class _GatedProber implements StreamProber {
  _GatedProber(this._gate);

  final Completer<ProbeResult> _gate;

  @override
  Future<ProbeResult> probe(
    String url, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _gate.future;
  }
}
