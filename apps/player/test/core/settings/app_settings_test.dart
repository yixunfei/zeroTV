import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/core/settings/app_settings.dart';

void main() {
  late SharedPreferences prefs;
  late AppSettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = AppSettingsStore(prefs);
  });

  test('load returns defaults on a fresh store', () {
    final settings = store.load();
    expect(settings.syncInterval, const Duration(hours: 6));
    expect(settings.probeConcurrency, 16);
    expect(settings.bufferSizeBytes, 32 * 1024 * 1024);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.disclaimerAccepted, isFalse);
    expect(settings.locale, isNull);
  });

  test('save then load round-trips every field', () async {
    await store.save(
      const AppSettings(
        syncInterval: Duration(hours: 12),
        probeConcurrency: 32,
        bufferSizeBytes: 64 * 1024 * 1024,
        themeMode: ThemeMode.dark,
      ),
    );

    final settings = store.load();
    expect(settings.syncInterval, const Duration(hours: 12));
    expect(settings.probeConcurrency, 32);
    expect(settings.bufferSizeBytes, 64 * 1024 * 1024);
    expect(settings.themeMode, ThemeMode.dark);
  });

  test('null sync interval (manual only) survives a round-trip', () async {
    await store.save(const AppSettings(syncInterval: null));
    expect(store.load().syncInterval, isNull);
  });

  test('disclaimer acknowledgement survives a round-trip', () async {
    await store.save(const AppSettings(disclaimerAccepted: true));
    expect(store.load().disclaimerAccepted, isTrue);
  });

  test('locale round-trips and can be cleared back to system', () async {
    await store.save(const AppSettings(locale: Locale('en')));
    expect(store.load().locale, const Locale('en'));

    await store.save(store.load().copyWith(clearLocale: true));
    expect(store.load().locale, isNull);
  });

  test('copyWith clearLocale resets the locale to null', () {
    const settings = AppSettings(locale: Locale('zh'));
    expect(settings.copyWith(clearLocale: true).locale, isNull);
  });

  test('copyWith clearSyncInterval resets the interval to null', () {
    const settings = AppSettings(syncInterval: Duration(hours: 3));
    final cleared = settings.copyWith(clearSyncInterval: true);
    expect(cleared.syncInterval, isNull);
  });
}
