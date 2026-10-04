import 'dart:async';

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
  const ProbeScanDone(this.available, this.total, {this.results = const {}});

  /// Number of channels reported available.
  final int available;

  /// Total channels probed.
  final int total;

  /// Final results remain visible while the database stream catches up.
  final Map<String, ProbeResult> results;
}

/// Coordinates a batch availability scan over the given channels.
final probeScanProvider = NotifierProvider<ProbeScanNotifier, ProbeScanState>(
  ProbeScanNotifier.new,
);

/// Drives [RunAvailabilityProbe] and exposes scan progress to the UI.
class ProbeScanNotifier extends Notifier<ProbeScanState> {
  /// Generation token: bumped on every start/cancel so a stale scan
  /// loop stops touching [state] after a cancel superseded it.
  int _generation = 0;

  StreamSubscription<ProbeProgress>? _scanSub;
  Completer<void>? _scanDone;

  @override
  ProbeScanState build() => const ProbeScanIdle();

  /// Probes [channels]; ignores the call while a scan is already running.
  Future<void> start(List<Channel> channels) async {
    if (state is ProbeScanRunning || channels.isEmpty) return;
    final generation = ++_generation;
    final total = channels.length;
    state = ProbeScanRunning(
      ProbeProgress(total: total, completed: 0, results: const {}),
    );
    final run = ref.read(runAvailabilityProbeProvider);
    final done = Completer<void>();
    var available = 0;
    var latest = <String, ProbeResult>{};
    StreamSubscription<ProbeProgress>? sub;
    try {
      sub = run(channels).listen(
        (progress) {
          latest = progress.results;
          available = progress.results.values
              .where((r) => r.isAvailable)
              .length;
          state = ProbeScanRunning(progress);
        },
        onError: (Object _) {
          // The scan failed (network down, probe worker crash): fall
          // back to idle so the scan button becomes usable again. The
          // failure is already surfaced through the scan snackbar.
          if (generation == _generation) state = const ProbeScanIdle();
          done.complete();
        },
        onDone: () {
          if (generation == _generation) {
            state = ProbeScanDone(available, total, results: latest);
          }
          done.complete();
        },
        cancelOnError: true,
      );
      _scanSub = sub;
      _scanDone = done;
      await done.future;
    } on Object {
      if (generation == _generation) state = const ProbeScanIdle();
    } finally {
      if (identical(_scanSub, sub)) _scanSub = null;
      if (identical(_scanDone, done)) _scanDone = null;
    }
  }

  /// Aborts the running scan immediately (results persisted so far are
  /// kept); does nothing when no scan is running.
  void cancel() {
    if (state is! ProbeScanRunning) return;
    _generation++;
    state = const ProbeScanIdle();
    // Actually cancel the probe stream: without this the old scan would
    // keep probing (and persisting results) until its next progress
    // event, racing a scan started right after the cancel.
    final sub = _scanSub;
    _scanSub = null;
    if (sub != null) unawaited(sub.cancel());
    // Cancelling the subscription never fires onDone; release the
    // pending start() so it doesn't await forever.
    final done = _scanDone;
    _scanDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }
}
