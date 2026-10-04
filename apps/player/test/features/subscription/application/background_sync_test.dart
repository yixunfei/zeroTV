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

  test(
    'manual scheduler stays idle and can resume with a new interval',
    () async {
      final sync = _FakeAutoSync(const []);
      final scheduler = BackgroundSyncScheduler(
        sync: sync,
        interval: null,
        isAndroid: false,
      );
      addTearDown(scheduler.stop);
      await scheduler.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(sync.calls, 0);
      await scheduler.setInterval(const Duration(milliseconds: 15));
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(sync.calls, greaterThan(0));
      expect(sync.lastInterval, const Duration(milliseconds: 15));
      await scheduler.setInterval(null);
      final calls = sync.calls;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(sync.calls, calls);
    },
  );

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
  Duration? lastInterval;

  @override
  Future<List<SyncFailure>> syncDue({
    Duration? intervalOverride,
    void Function(int completed, int total)? onProgress,
  }) async {
    calls++;
    lastInterval = intervalOverride;
    onProgress?.call(0, 0);
    return _failures;
  }

  @override
  Future<List<SyncFailure>> syncAll({
    void Function(int completed, int total)? onProgress,
  }) => syncDue(onProgress: onProgress);
}
