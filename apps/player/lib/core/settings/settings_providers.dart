import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/core/settings/app_settings.dart';

/// Provides the [AppSettingsStore].
final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore(ref.watch(sharedPreferencesProvider));
});

/// Current app settings; defaults are read from storage on first build.
final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

/// Loads and persists [AppSettings].
class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(appSettingsStoreProvider).load();

  /// Replaces the settings and persists them.
  Future<void> update(AppSettings settings) async {
    // Persist before touching state: writing state first would leave the
    // UI on the new value while storage still holds the old one when the
    // save fails (silently reverting after a restart).
    await ref.read(appSettingsStoreProvider).save(settings);
    state = settings;
  }

  /// Updates just the sync interval; null disables automatic sync.
  Future<void> setSyncInterval(Duration? interval) {
    return update(
      state.copyWith(
        syncInterval: interval,
        clearSyncInterval: interval == null,
      ),
    );
  }

  /// Updates the probe concurrency.
  Future<void> setProbeConcurrency(int concurrency) {
    return update(state.copyWith(probeConcurrency: concurrency));
  }

  /// Updates the player buffer size.
  Future<void> setBufferSize(int bytes) {
    return update(state.copyWith(bufferSizeBytes: bytes));
  }

  /// Updates the theme mode.
  Future<void> setThemeMode(ThemeMode mode) {
    return update(state.copyWith(themeMode: mode));
  }

  /// Records that the first-run disclaimer was acknowledged.
  Future<void> acceptDisclaimer() {
    return update(state.copyWith(disclaimerAccepted: true));
  }

  /// Enables or disables the overseas-network warning.
  Future<void> setOverseasNetworkHint({required bool enabled}) {
    return update(state.copyWith(showOverseasNetworkHint: enabled));
  }

  /// Sets the UI locale; null follows the system locale.
  Future<void> setLocale(Locale? locale) {
    return update(
      state.copyWith(locale: locale, clearLocale: locale == null),
    );
  }
}
