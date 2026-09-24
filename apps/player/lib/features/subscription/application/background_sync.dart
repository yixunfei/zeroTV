import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
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
Future<bool> runBackgroundSync({ProviderContainer? container}) async {
  final ownsContainer = container == null;
  final resolved = container ?? await _createContainer();
  try {
    final failures = await resolved.read(autoSyncServiceProvider).syncDue();
    return failures.isEmpty;
  } finally {
    if (ownsContainer) resolved.dispose();
  }
}

Future<ProviderContainer> _createContainer() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
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
    Duration interval = const Duration(hours: 1),
    bool? isAndroid,
  }) : _sync = sync,
       _interval = interval,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  final AutoSyncService _sync;
  final Duration _interval;
  final bool _isAndroid;
  Timer? _timer;

  /// Starts scheduling; safe to call once at startup.
  Future<void> start() async {
    if (_isAndroid) {
      try {
        await Workmanager().initialize(backgroundSyncDispatcher);
        await Workmanager().registerPeriodicTask(
          backgroundSyncUniqueName,
          backgroundSyncTaskName,
          frequency: _interval,
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        );
      } on Object {
        // Background scheduling is best-effort; never block app startup.
      }
    } else {
      _timer ??= Timer.periodic(_interval, (_) => unawaited(_sync.syncDue()));
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
  );
  ref.onDispose(scheduler.stop);
  return scheduler;
});
