import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/features/channel/application/channel_filter.dart';
import 'package:zerotv_player/features/channel/application/resolve_channel_sources.dart';
import 'package:zerotv_player/features/channel/application/toggle_dead.dart';
import 'package:zerotv_player/features/channel/application/toggle_favorite.dart';
import 'package:zerotv_player/features/channel/data/drift_channel_repository.dart';
import 'package:zerotv_player/features/channel/data/drift_dead_channel_repository.dart';
import 'package:zerotv_player/features/channel/data/drift_favorites_repository.dart';
import 'package:zerotv_player/features/channel/data/drift_watch_history_repository.dart';
import 'package:zerotv_player/features/detection/application/probe_scan_controller.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/epg/application/epg_index.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';

/// Provides the [ChannelRepository].
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return DriftChannelRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [ResolveChannelSources] use case.
final resolveChannelSourcesProvider = Provider<ResolveChannelSources>((ref) {
  return const ResolveChannelSources();
});

/// Provides the [FavoritesRepository].
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return DriftFavoritesRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [WatchHistoryRepository].
final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  return DriftWatchHistoryRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [DeadChannelRepository].
final deadChannelRepositoryProvider = Provider<DeadChannelRepository>((ref) {
  return DriftDeadChannelRepository(ref.watch(appDatabaseProvider));
});

/// Identity keys of channels the user marked as dead.
final deadKeysProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(deadChannelRepositoryProvider).watchKeys();
});

/// All dead-marked channels, latest first.
final deadChannelsProvider = StreamProvider<List<DeadChannel>>((ref) {
  return ref.watch(deadChannelRepositoryProvider).watchAll();
});

/// Provides the [ToggleFavorite] use case.
final toggleFavoriteProvider = Provider<ToggleFavorite>((ref) {
  return ToggleFavorite(favorites: ref.watch(favoritesRepositoryProvider));
});

/// Provides the [ToggleDead] use case.
final toggleDeadProvider = Provider<ToggleDead>((ref) {
  return ToggleDead(dead: ref.watch(deadChannelRepositoryProvider));
});

/// All channels across subscriptions, unfiltered.
final allChannelsProvider = StreamProvider<List<Channel>>((ref) {
  return ref.watch(channelRepositoryProvider).watchAll();
});

/// All channels minus the ones the user marked as dead.
final aliveChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  return _combine(
    ref.watch(allChannelsProvider),
    ref.watch(deadKeysProvider),
    (channels, deadKeys) => [
      for (final c in channels)
        if (!deadKeys.contains(c.identityKey)) c,
    ],
  );
});

/// All distinct group titles across subscriptions, sorted.
final allGroupsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(channelRepositoryProvider).watchAllGroups();
});

/// Channel counts per subscription, keyed by subscription id.
final channelCountsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(channelRepositoryProvider).watchCountsBySubscription();
});

/// Current favorite channel keys.
final favoriteKeysProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(favoritesRepositoryProvider).watchKeys();
});

/// Favorite channels (alive only), in list order. Backs the favorites
/// management page.
final favoriteChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  return _combine(
    ref.watch(aliveChannelsProvider),
    ref.watch(favoriteKeysProvider),
    (channels, keys) => [
      for (final c in channels)
        if (keys.contains(c.identityKey)) c,
    ],
  );
});

/// Recent watch history, one entry per channel, latest first.
final recentHistoryProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(watchHistoryRepositoryProvider).watchRecent();
});

/// Currently selected channel filter; defaults to [FilterAll].
final channelFilterProvider =
    NotifierProvider<ChannelFilterNotifier, ChannelFilter>(
      ChannelFilterNotifier.new,
    );

/// Stored probe results merged with the in-flight scan snapshot. The scan
/// snapshot makes the available tab react as soon as one channel finishes,
/// without waiting for the database stream notification to round-trip.
final effectiveProbeResultsProvider =
    Provider<AsyncValue<Map<String, ProbeResult>>>((ref) {
      final stored = ref.watch(probeResultsProvider);
      final scan = ref.watch(probeScanProvider);

      final live = switch (scan) {
        ProbeScanRunning(:final progress) => progress.results,
        ProbeScanDone(:final results) => results,
        _ => const <String, ProbeResult>{},
      };
      if (live.isNotEmpty) {
        final merged = <String, ProbeResult>{};
        final storedResults = stored.value;
        if (storedResults != null) {
          merged.addAll(storedResults);
        }
        for (final entry in live.entries) {
          final saved = merged[entry.key];
          if (saved == null ||
              !saved.checkedAt.isAfter(entry.value.checkedAt)) {
            merged[entry.key] = entry.value;
          }
        }
        return AsyncData(merged);
      }

      return stored;
    });

/// Holds the selected channel filter.
class ChannelFilterNotifier extends Notifier<ChannelFilter> {
  @override
  ChannelFilter build() => const FilterAvailable();

  /// The current filter.
  ChannelFilter get current => state;

  /// Sets the current filter.
  set current(ChannelFilter filter) => state = filter;
}

/// Channels shown in the list, honoring [channelFilterProvider].
///
/// Dead-marked channels are hidden from every view except the dedicated
/// dead-channel management page.
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final channels = ref.watch(aliveChannelsProvider);
  return switch (ref.watch(channelFilterProvider)) {
    FilterAll() => channels,
    FilterGroup(:final group) => channels.whenData(
      (cs) => [
        for (final c in cs)
          if ((c.groupTitle ?? ungroupedGroupLabel) == group) c,
      ],
    ),
    FilterFavorites() => _combine(
      channels,
      ref.watch(favoriteKeysProvider),
      (cs, keys) => [
        for (final c in cs)
          if (keys.contains(c.identityKey)) c,
      ],
    ),
    FilterRecent() => _combine(
      channels,
      ref.watch(recentHistoryProvider),
      _recentOrdered,
    ),
    FilterSearch(:final query) => _combine(
      channels,
      ref.watch(epgIndexProvider),
      (cs, index) => _searchByNameOrProgram(cs, index, query),
    ),
    FilterAvailable() => _combine(
      channels,
      ref.watch(effectiveProbeResultsProvider),
      (cs, results) => [
        for (final c in cs)
          if (results[c.identityKey]?.isAvailable ?? false) c,
      ],
    ),
  };
});

/// Search matches channel name, or the title of the programme currently
/// airing on the channel (when EPG data is available).
List<Channel> _searchByNameOrProgram(
  List<Channel> channels,
  EpgIndex index,
  String query,
) {
  final needle = query.toLowerCase();
  return [
    for (final c in channels)
      if (c.name.toLowerCase().contains(needle) ||
          (index.forChannel(c)?.now?.title.toLowerCase().contains(needle) ??
              false))
        c,
  ];
}

/// Orders channels by recency of watching; channels whose source
/// disappeared upstream are skipped.
List<Channel> _recentOrdered(
  List<Channel> channels,
  List<HistoryEntry> history,
) {
  final byKey = <String, Channel>{};
  for (final c in channels) {
    byKey.putIfAbsent(c.identityKey, () => c);
  }
  return [for (final e in history) ?byKey[e.channelKey]];
}

/// Combines two async values; errors win over loading, loading wins
/// over data.
AsyncValue<R> _combine<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) combine,
) {
  if (a case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (b case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  final av = a.value;
  final bv = b.value;
  if (av == null || bv == null) return const AsyncLoading();
  return AsyncData(combine(av, bv));
}

/// The most recently watched channel that still exists upstream,
/// or null when there is no usable history entry. Used by the
/// "resume watching" banner on the channel list.
final lastWatchedChannelProvider = Provider<Channel?>((ref) {
  final channels = ref.watch(aliveChannelsProvider).value;
  final history = ref.watch(recentHistoryProvider).value;
  if (channels == null || history == null || history.isEmpty) return null;
  final recent = _recentOrdered(channels, history);
  if (recent.isNotEmpty) {
    return recent.first;
  }
  return null;
});
