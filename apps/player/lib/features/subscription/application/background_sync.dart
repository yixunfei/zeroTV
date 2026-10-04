import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/core/settings/settings_providers.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Task name reported to the background isolate.
const backgroundSyncTaskName = 'zerotv.subscriptionSync';

/// Unique name of the registered periodic background task.
const backgroundSyncUniqueName = 'zerotv.subscriptionSync.periodic';

/// Entry point for the Android background isolate.
///
/// Must be a top-level function annotated with `@pragma('vm:entry-point')`
/// so the Dart compiler keeps it reachable for background starts.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTaskName) return true;
    return runBackgroundSync();
  });
}

/// Runs one auto-sync pass in the current isolate.
///
/// Returns true when no subscription failed, so the platform can decide
/// whether to retry. A [container] may be injected for tests; otherwise a
/// minimal container (only shared_preferences overridden) is built, with
/// plugin registration performed for the background isolate.
///
/// Honors the user's global sync-interval setting: when it is null
/// ("manual only"), the pass is a no-op.
Future<bool> runBackgroundSync({ProviderContainer? container}) async {
  final ownsContainer = container == null;
  final resolved = container ?? await _createContainer();
  try {
    final interval = resolved.read(appSettingsProvider).syncInterval;
    if (interval == null) return true;
    final failures = await resolved
        .read(autoSyncServiceProvider)
        .syncDue(intervalOverride: interval);
    return failures.isEmpty;
  } finally {
    if (ownsContainer) resolved.dispose();
  }
}

Future<ProviderContainer> _createContainer() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

/// Schedules automatic subscription sync.
///
/// On Android this registers a WorkManager periodic task (survives app
/// restarts); elsewhere (desktop has no reliable background mechanism) it
/// runs an in-app timer. In both cases [AutoSyncService.syncDue] gates the
/// actual work by each subscription's own interval.
class BackgroundSyncScheduler {
  /// Creates the scheduler.
  BackgroundSyncScheduler({
    required AutoSyncService sync,
    Duration? interval = const Duration(hours: 1),
    bool? isAndroid,
  }) : _sync = sync,
       _interval = interval,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  final AutoSyncService _sync;
  Duration? _interval;
  final bool _isAndroid;
  Timer? _timer;
  bool _running = false;
  Future<void> _configuration = Future<void>.value();

  /// Applies a changed preference without replacing the active scheduler.
  Future<void> setInterval(Duration? interval) {
    _interval = interval;
    stop();
    return start();
  }

  /// Starts scheduling; safe to call once at startup.
  Future<void> start() {
    return _configuration = _configuration.then((_) => _configure());
  }

  Future<void> _configure() async {
    final interval = _interval;
    if (_isAndroid) {
      try {
        await Workmanager().initialize(backgroundSyncDispatcher);
        if (interval == null) {
          await Workmanager().cancelByUniqueName(backgroundSyncUniqueName);
          return;
        }
        await Workmanager().registerPeriodicTask(
          backgroundSyncUniqueName,
          backgroundSyncTaskName,
          frequency: interval < const Duration(minutes: 15)
              ? const Duration(minutes: 15)
              : interval,
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        );
      } on Object {
        // Background scheduling is best-effort; never block app startup.
      }
    } else if (interval != null) {
      _timer ??= Timer.periodic(interval, (_) => unawaited(_syncOnce()));
    }
  }

  Future<void> _syncOnce() async {
    final interval = _interval;
    if (_running || interval == null) return;
    _running = true;
    try {
      await _sync.syncDue(intervalOverride: interval);
    } on Object {
      // A transient database/network failure must not escape the timer.
    } finally {
      _running = false;
    }
  }

  /// Cancels the in-app timer (no-op on Android).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provides the app-wide [BackgroundSyncScheduler].
final backgroundSyncSchedulerProvider = Provider<BackgroundSyncScheduler>((
  ref,
) {
  final scheduler = BackgroundSyncScheduler(
    sync: ref.watch(autoSyncServiceProvider),
    interval: ref.read(appSettingsProvider).syncInterval,
  );
  ref
    ..listen(appSettingsProvider.select((s) => s.syncInterval), (_, interval) {
      unawaited(scheduler.setInterval(interval));
    })
    ..onDispose(scheduler.stop);
  return scheduler;
});
