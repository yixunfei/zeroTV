import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/epg/application/epg_guide.dart';
import 'package:zerotv_player/features/epg/application/epg_index.dart';
import 'package:zerotv_player/features/epg/application/epg_settings.dart';
import 'package:zerotv_player/features/epg/application/refresh_epg.dart';
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

/// Provides the [RefreshEpg] use case (interval-gated auto refresh).
final refreshEpgProvider = Provider<RefreshEpg>((ref) {
  return RefreshEpg(
    sync: ref.watch(syncEpgProvider),
    settings: ref.watch(epgSettingsProvider),
  );
});

/// The configured EPG URL, or null when unset.
final epgUrlProvider = Provider<Uri?>((ref) {
  return ref.watch(epgSettingsProvider).url;
});

/// Adopts a playlist-advertised EPG URL (`x-tvg-url`) as the configured
/// source, but only while the user has not configured one themselves —
/// an explicit user choice is never silently replaced by a source's
/// pointer. Wired into subscription sync (SyncSubscription).
final adoptPlaylistEpgUrlProvider = Provider<Future<void> Function(Uri epgUrl)>(
  (ref) {
    return (Uri epgUrl) async {
      final settings = ref.read(epgSettingsProvider);
      if (settings.url != null) return;
      await settings.setUrl('$epgUrl');
      // The URL provider caches the read; refresh it so dependent
      // widgets (settings page, guide) see the adopted source.
      ref.invalidate(epgUrlProvider);
    };
  },
);

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
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
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

/// Query key for [channelGuideProvider]: XMLTV channel id + local day.
typedef ChannelGuideQuery = ({String epgId, DateTime day});

/// One full day of programmes for one XMLTV channel, backing the
/// guide page. The query day is truncated to local midnight.
final FutureProvider<List<EpgProgram>> Function(ChannelGuideQuery query)
channelGuideProvider = FutureProvider.autoDispose
    .family<List<EpgProgram>, ChannelGuideQuery>((
      ref,
      query,
    ) async {
      final d = query.day;
      final start = DateTime(d.year, d.month, d.day);
      return ref
          .watch(epgRepositoryProvider)
          .programmesFor(
            query.epgId,
            start,
            start.add(const Duration(days: 1)),
          );
    })
    .call;

/// Now/next index for resolving programmes against app channels.
///
/// Combines XMLTV channel metadata (for name fallback and coverage
/// detection) with the now/next map. Empty when no EPG data is stored.
final epgIndexProvider = FutureProvider<EpgIndex>((ref) async {
  final repository = ref.watch(epgRepositoryProvider);
  final channels = await repository.allChannels();
  if (channels.isEmpty) return EpgIndex.empty;
  final nowNext = await ref.watch(nowNextByEpgIdProvider.future);
  final byName = <String, String>{};
  for (final c in channels) {
    byName.putIfAbsent(EpgIndex.normalize(c.displayName), () => c.id);
  }
  return EpgIndex(
    byEpgId: nowNext,
    byNormalizedName: byName,
    knownEpgIds: {for (final c in channels) c.id},
  );
});
