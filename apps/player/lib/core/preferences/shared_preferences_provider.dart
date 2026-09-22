import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the app-wide [SharedPreferences] instance.
///
/// Throws unless overridden in `main` (tests override or use
/// `SharedPreferences.setMockInitialValues`).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});
