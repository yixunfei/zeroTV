import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotv_player/features/epg/application/epg_settings.dart';
import 'package:zerotv_player/features/epg/application/refresh_epg.dart';
import 'package:zerotv_player/features/epg/application/sync_epg.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  RefreshEpg buildRefresh(
    SharedPreferences prefs, {
    required void Function() onSync,
    EpgFeed? Function() behavior = _okFeed,
    DateTime Function()? now,
  }) {
    return RefreshEpg(
      sync: _RecordingSync(behavior, onSync),
      settings: EpgSettings(prefs),
      now: now ?? DateTime.now,
    );
  }

  test('refreshes when no sync has ever run', () async {
    final prefs = await prefsWith({
      'epg_url': 'https://example.com/epg.xml',
    });
    var syncCalls = 0;
    final refresh = buildRefresh(prefs, onSync: () => syncCalls++);

    final ran = await refresh();

    expect(ran, isTrue);
    expect(syncCalls, 1);
  });

  test('skips when the stored data is still fresh', () async {
    final prefs = await prefsWith({
      'epg_url': 'https://example.com/epg.xml',
      'epg_last_synced_at': DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    });
    var syncCalls = 0;
    final refresh = buildRefresh(prefs, onSync: () => syncCalls++);

    final ran = await refresh();

    expect(ran, isFalse);
    expect(syncCalls, 0);
  });

  test('refreshes when the stored data has expired', () async {
    final prefs = await prefsWith({
      'epg_url': 'https://example.com/epg.xml',
      'epg_last_synced_at': DateTime.now()
          .subtract(const Duration(hours: 13))
          .millisecondsSinceEpoch,
    });
    var syncCalls = 0;
    final refresh = buildRefresh(prefs, onSync: () => syncCalls++);

    final ran = await refresh();

    expect(ran, isTrue);
    expect(syncCalls, 1);
  });

  test('is a no-op when no EPG URL is configured', () async {
    final prefs = await prefsWith({});
    var syncCalls = 0;
    final refresh = buildRefresh(prefs, onSync: () => syncCalls++);

    final ran = await refresh();

    expect(ran, isFalse);
    expect(syncCalls, 0);
  });

  test('a failed refresh reports false and keeps the old stamp', () async {
    final prefs = await prefsWith({
      'epg_url': 'https://example.com/epg.xml',
    });
    final refresh = buildRefresh(
      prefs,
      onSync: () {},
      behavior: () => throw const SubscriptionFetchException(
        SyncErrorReason.epgFetchFailed,
        'offline',
      ),
    );

    final ran = await refresh();

    expect(ran, isFalse);
    expect(EpgSettings(prefs).lastSyncedAt, isNull);
  });

  test('a successful refresh stamps the sync time', () async {
    final prefs = await prefsWith({
      'epg_url': 'https://example.com/epg.xml',
    });
    final fixed = DateTime(2026, 10, 6, 12);
    // The stamp is written by the real SyncEpg (refresh only gates it),
    // so exercise SyncEpg directly with a stubbed provider/repository.
    final sync = _StubSyncEpg(
      settings: EpgSettings(prefs),
      now: () => fixed,
    );

    await sync();

    expect(EpgSettings(prefs).lastSyncedAt!.isAtSameMomentAs(fixed), isTrue);
  });
}

EpgFeed? _okFeed() => EpgFeed.empty;

/// A [SyncEpg] with fetch and persist stubbed out, keeping the real
/// last-sync stamping behavior under test.
class _StubSyncEpg extends SyncEpg {
  _StubSyncEpg({required super.settings, required super.now})
    : super(provider: _StubEpgProvider(), repository: _StubEpgRepository());
}

class _StubEpgProvider implements EpgProvider {
  @override
  Future<EpgFeed> fetch(Uri uri) async => EpgFeed.empty;
}

class _StubEpgRepository implements EpgRepository {
  @override
  Future<List<EpgChannel>> allChannels() async => const [];

  @override
  Future<List<EpgProgram>> programmesFor(
    String channelId,
    DateTime from,
    DateTime to,
  ) async => const [];

  @override
  Future<List<EpgProgram>> programmesInWindow(
    DateTime from,
    DateTime to,
  ) async => const [];

  @override
  Future<void> replaceFeed(EpgFeed feed) async {}

  @override
  Future<void> clear() async {}
}

/// A [SyncEpg] stand-in that records invocations without touching the
/// real repository or provider chain.
class _RecordingSync implements SyncEpg {
  _RecordingSync(this._behavior, this._onCalled);

  final EpgFeed? Function() _behavior;
  final void Function() _onCalled;

  @override
  Future<EpgFeed?> call() async {
    _onCalled();
    return _behavior();
  }
}
