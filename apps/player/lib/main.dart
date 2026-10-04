import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/app.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/recording/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  // Finalize recordings orphaned by a crash or process kill (best-effort:
  // a failure must not crash startup; the rows are retried next launch).
  unawaited(() async {
    try {
      await container.read(manageRecordingProvider).recoverOrphans();
    } on Object {
      // Best-effort recovery only.
    }
  }());
  // Poll EPG-based scheduled recordings: fires due windows and stops
  // finished ones while the app runs (best-effort, see scheduler docs).
  unawaited(() async {
    try {
      container.read(recordingSchedulerProvider).start();
    } on Object {
      // Scheduling must never crash startup.
    }
  }());
  // Scheduling is best-effort and must never delay the first frame. The
  // channel page starts its local seeding and background sync independently.
  unawaited(container.read(backgroundSyncSchedulerProvider).start());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZeroTvApp(),
    ),
  );
}
