import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';
import 'package:zerotv_player/features/epg/application/epg_settings.dart';
import 'package:zerotv_player/features/epg/application/sync_epg.dart';
import 'package:zerotv_player/features/epg/data/drift_epg_repository.dart';
import 'package:zerotv_player/features/epg/data/http_epg_provider.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Provides the [EpgSettings] store.
final epgSettingsProvider = Provider<EpgSettings>((ref) {
  return EpgSettings(ref.watch(sharedPreferencesProvider));
});

/// Provides the [EpgRepository].
final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  return DriftEpgRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [EpgProvider] (remote XMLTV over HTTP).
final epgFeedProvider = Provider<EpgProvider>((ref) {
  return HttpEpgProvider(dio: ref.watch(dioProvider));
});

/// Provides the [SyncEpg] use case.
final syncEpgProvider = Provider<SyncEpg>((ref) {
  return SyncEpg(
    provider: ref.watch(epgFeedProvider),
    repository: ref.watch(epgRepositoryProvider),
    settings: ref.watch(epgSettingsProvider),
  );
});

/// The configured EPG URL, or null when unset.
final epgUrlProvider = Provider<Uri?>((ref) {
  return ref.watch(epgSettingsProvider).url;
});

/// Number of stored EPG programmes overlapping the next 24 hours.
///
/// EPG data is static (not a drift stream); callers invalidate this after a
/// successful sync.
final epgProgrammeCountProvider = FutureProvider<int>((ref) async {
  final now = DateTime.now();
  final programmes = await ref
      .watch(epgRepositoryProvider)
      .programmesInWindow(now, now.add(const Duration(hours: 24)));
  return programmes.length;
});

/// Now/next guide keyed by XMLTV channel id, over the next few hours.
///
/// EPG data is static (not a drift stream); callers invalidate this after a
/// successful sync.
final nowNextByEpgIdProvider = FutureProvider<Map<String, NowNext>>((
  ref,
) async {
  final now = DateTime.now();
  final programmes = await ref
      .watch(epgRepositoryProvider)
      .programmesInWindow(now, now.add(const Duration(hours: 6)));
  final byChannel = <String, List<EpgProgram>>{};
  for (final p in programmes) {
    byChannel.putIfAbsent(p.channelId, () => []).add(p);
  }
  final guide = EpgGuide(from: now, to: now.add(const Duration(hours: 6)));
  return {
    for (final entry in byChannel.entries)
      entry.key: guide.resolve(entry.value),
  };
});
