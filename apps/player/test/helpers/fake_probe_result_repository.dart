import 'package:iptv_core/iptv_core.dart';

/// In-memory [ProbeResultRepository] for widget tests: no drift, no
/// pending timers. Mirrors the static-stream style of the other fakes.
class FakeProbeResultRepository implements ProbeResultRepository {
  /// Creates the fake with optional initial results.
  FakeProbeResultRepository([Map<String, ProbeResult>? initial])
    : _results = {...?initial};

  final Map<String, ProbeResult> _results;

  @override
  Stream<Map<String, ProbeResult>> watchAll() => Stream.value(_results);

  @override
  Future<void> save(String channelKey, ProbeResult result) async {
    _results[channelKey] = result;
  }

  @override
  Future<void> clear() async => _results.clear();
}
