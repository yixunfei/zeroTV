import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';

import '../../../helpers/fake_probe_result_repository.dart';

void main() {
  const channels = [
    Channel(name: 'A', streamUrl: 'http://a/1'),
    Channel(name: 'B', streamUrl: 'http://b/2'),
  ];

  test('probes every channel and persists each result', () async {
    final results = FakeProbeResultRepository();
    final run = RunAvailabilityProbe(
      prober: _StubProber({
        'http://a/1': ProbeStatus.ok,
        'http://b/2': ProbeStatus.dead,
      }),
      results: results,
    );

    final progress = await run(channels).toList();

    expect(progress.first.completed, 0);
    expect(progress.last.total, 2);
    expect(progress.last.isDone, isTrue);
    expect(progress.last.results, hasLength(2));
    expect(
      progress.last.results['a']?.status,
      ProbeStatus.ok,
    );
    expect(
      progress.last.results['b']?.status,
      ProbeStatus.dead,
    );

    final stored = await results.watchAll().first;
    expect(stored, hasLength(2));
  });

  test('duplicates finish progress and preserve a working fallback', () async {
    final run = RunAvailabilityProbe(
      prober: _StubProber({
        'http://a/1': ProbeStatus.ok,
        'http://b/2': ProbeStatus.dead,
      }),
      results: FakeProbeResultRepository(),
      concurrency: 1,
    );
    final progress = await run(const [
      Channel(name: 'A', streamUrl: 'http://a/1'),
      Channel(name: 'B', streamUrl: 'http://a/1'),
      Channel(name: 'A', streamUrl: 'http://b/2'),
    ]).toList();
    expect(progress.first.results, isEmpty);
    expect(progress.last.completed, 3);
    expect(progress.last.isDone, isTrue);
    expect(progress.last.results['a']!.status, ProbeStatus.ok);
    expect(progress.last.results['b']!.status, ProbeStatus.ok);
  });

  test('empty channel list yields a single done snapshot', () async {
    final run = RunAvailabilityProbe(
      prober: _StubProber(const {}),
      results: FakeProbeResultRepository(),
    );

    final progress = await run(const []).toList();

    expect(progress, hasLength(1));
    expect(progress.single.total, 0);
    expect(progress.single.isDone, isTrue);
  });

  test('keeps the lowest latency available source for one channel', () async {
    final run = RunAvailabilityProbe(
      prober: _LatencyProber(),
      results: FakeProbeResultRepository(),
      concurrency: 1,
    );
    final progress = await run(const [
      Channel(name: 'A', streamUrl: 'http://slow'),
      Channel(name: 'A', streamUrl: 'http://fast'),
    ]).toList();

    expect(progress.last.results['a']?.url, 'http://fast');
    expect(
      progress.last.results['a']?.latency,
      const Duration(milliseconds: 20),
    );
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

class _LatencyProber implements StreamProber {
  @override
  Future<ProbeResult> probe(
    String url, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final latency = url.endsWith('fast') ? 20 : 120;
    return ProbeResult(
      url: url,
      status: ProbeStatus.ok,
      checkedAt: DateTime(2026, 9, 22, 8),
      latency: Duration(milliseconds: latency),
    );
  }
}
