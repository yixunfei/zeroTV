import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/background_sync.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

void main() {
  Future<SharedPreferences> mockPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  test('runBackgroundSync reports success when nothing fails', () async {
    final prefs = await mockPrefs();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        autoSyncServiceProvider.overrideWithValue(_FakeAutoSync(const [])),
      ],
    );
    addTearDown(container.dispose);

    expect(await runBackgroundSync(container: container), isTrue);
  });

  test('runBackgroundSync reports failure when a subscription fails', () async {
    final prefs = await mockPrefs();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        autoSyncServiceProvider.overrideWithValue(
          _FakeAutoSync(const [SyncFailure('s1', 'boom')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await runBackgroundSync(container: container), isFalse);
  });

  test('runBackgroundSync skips work when sync is manual only', () async {
    SharedPreferences.setMockInitialValues({
      'settings.syncIntervalMinutes': 0,
    });
    final prefs = await SharedPreferences.getInstance();
    final sync = _FakeAutoSync(const []);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        autoSyncServiceProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);

    expect(await runBackgroundSync(container: container), isTrue);
    expect(sync.calls, 0);
  });

  test('non-Android scheduler uses an in-app timer', () async {
    final sync = _FakeAutoSync(const []);
    final scheduler = BackgroundSyncScheduler(
      sync: sync,
      interval: const Duration(milliseconds: 20),
      isAndroid: false,
    );

    await scheduler.start();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    scheduler.stop();

    expect(sync.calls, greaterThanOrEqualTo(2));
  });

  test('stop cancels the in-app timer', () async {
    final sync = _FakeAutoSync(const []);
    final scheduler = BackgroundSyncScheduler(
      sync: sync,
      interval: const Duration(milliseconds: 20),
      isAndroid: false,
    );

    await scheduler.start();
    scheduler.stop();
    final callsAtStop = sync.calls;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(sync.calls, callsAtStop);
  });
}

class _FakeAutoSync implements AutoSyncService {
  _FakeAutoSync(this._failures);

  final List<SyncFailure> _failures;
  int calls = 0;

  @override
  Future<List<SyncFailure>> syncDue({Duration? intervalOverride}) async {
    calls++;
    return _failures;
  }
}
