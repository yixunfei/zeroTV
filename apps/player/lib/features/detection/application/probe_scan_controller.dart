import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/detection/application/run_availability_probe.dart';

/// UI state of an availability scan.
sealed class ProbeScanState {
  /// Creates a state.
  const ProbeScanState();
}

/// No scan has been run in this session.
final class ProbeScanIdle extends ProbeScanState {
  /// Creates the state.
  const ProbeScanIdle();
}

/// A scan is running.
final class ProbeScanRunning extends ProbeScanState {
  /// Creates the state.
  const ProbeScanRunning(this.progress);

  /// Latest progress snapshot.
  final ProbeProgress progress;
}

/// The last scan finished.
final class ProbeScanDone extends ProbeScanState {
  /// Creates the state.
  const ProbeScanDone(this.available, this.total);

  /// Number of channels reported available.
  final int available;

  /// Total channels probed.
  final int total;
}

/// Coordinates a batch availability scan over the given channels.
final probeScanProvider = NotifierProvider<ProbeScanNotifier, ProbeScanState>(
  ProbeScanNotifier.new,
);

/// Drives [RunAvailabilityProbe] and exposes scan progress to the UI.
class ProbeScanNotifier extends Notifier<ProbeScanState> {
  @override
  ProbeScanState build() => const ProbeScanIdle();

  /// Probes [channels]; ignores the call while a scan is already running.
  Future<void> start(List<Channel> channels) async {
    if (state is ProbeScanRunning || channels.isEmpty) return;
    final total = channels.length;
    final run = ref.read(runAvailabilityProbeProvider);
    try {
      var available = 0;
      await for (final progress in run(channels)) {
        available = progress.results.values
            .where((r) => r.status == ProbeStatus.ok)
            .length;
        state = ProbeScanRunning(progress);
      }
      state = ProbeScanDone(available, total);
    } on Object {
      state = const ProbeScanIdle();
      rethrow;
    }
  }
}
