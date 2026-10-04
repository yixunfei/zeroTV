import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// State of the non-blocking startup sync.
sealed class BackgroundSyncState {
  const BackgroundSyncState();
}

/// No background sync has been started (or auto-sync is disabled).
final class BackgroundSyncIdle extends BackgroundSyncState {
  /// Creates the idle state.
  const BackgroundSyncIdle();
}

/// A background sync pass is currently running.
final class BackgroundSyncRunning extends BackgroundSyncState {
  /// Creates the running state.
  const BackgroundSyncRunning(this.completed, this.total);

  /// Number of subscriptions finished so far.
  final int completed;

  /// Number of subscriptions selected for this pass.
  final int total;
}

/// A background sync pass finished; [failures] is empty on full success.
final class BackgroundSyncDone extends BackgroundSyncState {
  /// Creates the done state with per-subscription [failures].
  const BackgroundSyncDone(this.failures);

  /// Per-subscription failures collected during the pass.
  final List<SyncFailure> failures;
}

/// Non-blocking startup sync, kicked off by `bootstrapProvider` after
/// seeding. Watch this to show a progress hint or report failures; the
/// UI itself must never be gated on it.
final backgroundSyncControllerProvider =
    NotifierProvider<BackgroundSyncController, BackgroundSyncState>(
      BackgroundSyncController.new,
    );

/// Runs due-subscription sync off the startup critical path. The UI may
/// watch this to show a subtle progress hint and surface failures, but
/// navigation and local data are never blocked on it.
class BackgroundSyncController extends Notifier<BackgroundSyncState> {
  Future<void>? _running;

  @override
  BackgroundSyncState build() => const BackgroundSyncIdle();

  /// Starts a due-sync pass unless one is already running or the user
  /// configured manual-only sync. Never throws.
  Future<void> run({bool all = false}) {
    final running = _running;
    if (running != null) return running;
    final future = _run(all: all);
    _running = future;
    return future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
  }

  Future<void> _run({required bool all}) async {
    final interval = ref.read(appSettingsProvider).syncInterval;
    if (!all && interval == null) return;
    state = const BackgroundSyncRunning(0, 0);
    try {
      final sync = ref.read(autoSyncServiceProvider);
      final failures = all
          ? await sync.syncAll(
              onProgress: (completed, total) {
                state = BackgroundSyncRunning(completed, total);
              },
            )
          : await sync.syncDue(
              intervalOverride: interval,
              onProgress: (completed, total) {
                state = BackgroundSyncRunning(completed, total);
              },
            );
      state = BackgroundSyncDone(failures);
    } on Object catch (e) {
      state = BackgroundSyncDone([SyncFailure('*', '$e')]);
    }
  }
}
