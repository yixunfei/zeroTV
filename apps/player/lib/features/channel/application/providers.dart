import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/features/channel/application/channel_filter.dart';
import 'package:zerotv_player/features/channel/application/toggle_favorite.dart';
import 'package:zerotv_player/features/channel/data/drift_channel_repository.dart';
import 'package:zerotv_player/features/channel/data/drift_favorites_repository.dart';
import 'package:zerotv_player/features/channel/data/drift_watch_history_repository.dart';

/// Provides the [ChannelRepository].
final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return DriftChannelRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [FavoritesRepository].
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return DriftFavoritesRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [WatchHistoryRepository].
final watchHistoryRepositoryProvider = Provider<WatchHistoryRepository>((ref) {
  return DriftWatchHistoryRepository(ref.watch(appDatabaseProvider));
});

/// Provides the [ToggleFavorite] use case.
final toggleFavoriteProvider = Provider<ToggleFavorite>((ref) {
  return ToggleFavorite(favorites: ref.watch(favoritesRepositoryProvider));
});

/// All channels across subscriptions, unfiltered.
final allChannelsProvider = StreamProvider<List<Channel>>((ref) {
  return ref.watch(channelRepositoryProvider).watchAll();
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

/// Recent watch history, one entry per channel, latest first.
final recentHistoryProvider = StreamProvider<List<HistoryEntry>>((ref) {
  return ref.watch(watchHistoryRepositoryProvider).watchRecent();
});

/// Currently selected channel filter; defaults to [FilterAll].
final channelFilterProvider =
    NotifierProvider<ChannelFilterNotifier, ChannelFilter>(
      ChannelFilterNotifier.new,
    );

/// Holds the selected channel filter.
class ChannelFilterNotifier extends Notifier<ChannelFilter> {
  @override
  ChannelFilter build() => const FilterAll();

  /// The current filter.
  ChannelFilter get current => state;

  /// Sets the current filter.
  set current(ChannelFilter filter) => state = filter;
}

/// Channels shown in the list, honoring [channelFilterProvider].
final filteredChannelsProvider = Provider<AsyncValue<List<Channel>>>((ref) {
  final channels = ref.watch(allChannelsProvider);
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
    FilterSearch(:final query) => channels.whenData(
      (cs) => [
        for (final c in cs)
          if (c.name.toLowerCase().contains(query.toLowerCase())) c,
      ],
    ),
  };
});

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
  final channels = ref.watch(allChannelsProvider).value;
  final history = ref.watch(recentHistoryProvider).value;
  if (channels == null || history == null || history.isEmpty) return null;
  final latest = history.first;
  for (final c in channels) {
    if (c.identityKey == latest.channelKey) return c;
  }
  return null;
});
