import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable snapshot of user-configurable app settings.
class AppSettings {
  /// Creates a settings snapshot.
  const AppSettings({
    this.syncInterval = const Duration(hours: 6),
    this.probeConcurrency = 16,
    this.bufferSizeBytes = 32 * 1024 * 1024,
    this.themeMode = ThemeMode.system,
    this.disclaimerAccepted = false,
    this.locale,
  });

  /// How often subscriptions auto-sync; null means manual only.
  final Duration? syncInterval;

  /// Maximum concurrent stream probes.
  final int probeConcurrency;

  /// Player buffer size in bytes (larger = more stable, higher latency).
  final int bufferSizeBytes;

  /// App-wide theme mode.
  final ThemeMode themeMode;

  /// Whether the user has acknowledged the first-run disclaimer.
  final bool disclaimerAccepted;

  /// Explicit UI locale; null follows the system locale.
  final Locale? locale;

  /// Returns a copy with the given fields replaced.
  AppSettings copyWith({
    Duration? syncInterval,
    bool clearSyncInterval = false,
    int? probeConcurrency,
    int? bufferSizeBytes,
    ThemeMode? themeMode,
    bool? disclaimerAccepted,
    Locale? locale,
    bool clearLocale = false,
  }) {
    return AppSettings(
      syncInterval: clearSyncInterval
          ? null
          : (syncInterval ?? this.syncInterval),
      probeConcurrency: probeConcurrency ?? this.probeConcurrency,
      bufferSizeBytes: bufferSizeBytes ?? this.bufferSizeBytes,
      themeMode: themeMode ?? this.themeMode,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      locale: clearLocale ? null : (locale ?? this.locale),
    );
  }
}

/// Persists [AppSettings] in [SharedPreferences].
class AppSettingsStore {
  /// Creates the store.
  const AppSettingsStore(this._prefs);

  static const _syncKey = 'settings.syncIntervalMinutes';
  static const _concurrencyKey = 'settings.probeConcurrency';
  static const _bufferKey = 'settings.bufferSizeBytes';
  static const _themeKey = 'settings.themeMode';
  static const _disclaimerKey = 'settings.disclaimerAccepted';
  static const _localeKey = 'settings.locale';

  final SharedPreferences _prefs;

  /// Reads the stored settings, falling back to defaults.
  AppSettings load() {
    final minutes = _prefs.getInt(_syncKey);
    return AppSettings(
      syncInterval: minutes == null
          ? const Duration(hours: 6)
          : _decodeSync(minutes),
      probeConcurrency: _prefs.getInt(_concurrencyKey) ?? 16,
      bufferSizeBytes: _prefs.getInt(_bufferKey) ?? 32 * 1024 * 1024,
      themeMode: _decodeTheme(_prefs.getString(_themeKey)),
      disclaimerAccepted: _prefs.getBool(_disclaimerKey) ?? false,
      locale: _decodeLocale(_prefs.getString(_localeKey)),
    );
  }

  /// Persists [settings].
  Future<void> save(AppSettings settings) async {
    final minutes = settings.syncInterval?.inMinutes;
    if (minutes == null) {
      await _prefs.setInt(_syncKey, 0); // 0 = manual only.
    } else {
      await _prefs.setInt(_syncKey, minutes);
    }
    await _prefs.setInt(_concurrencyKey, settings.probeConcurrency);
    await _prefs.setInt(_bufferKey, settings.bufferSizeBytes);
    await _prefs.setString(_themeKey, settings.themeMode.name);
    await _prefs.setBool(_disclaimerKey, settings.disclaimerAccepted);
    final code = settings.locale?.languageCode;
    if (code == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, code);
    }
  }

  Duration? _decodeSync(int minutes) =>
      minutes <= 0 ? null : Duration(minutes: minutes);

  Locale? _decodeLocale(String? code) {
    return switch (code) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null,
    };
  }

  ThemeMode _decodeTheme(String? name) {
    return switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
