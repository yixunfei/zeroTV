import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/app.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/subscription/application/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  await container.read(backgroundSyncSchedulerProvider).start();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZeroTvApp(),
    ),
  );
}
