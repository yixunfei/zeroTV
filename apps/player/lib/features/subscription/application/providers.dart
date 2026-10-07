import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/core/network/retry_interceptor.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/detection/application/providers.dart';
import 'package:zerotv_player/features/epg/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/add_subscription.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
import 'package:zerotv_player/features/subscription/application/background_sync_controller.dart';
import 'package:zerotv_player/features/subscription/application/default_source_seeder.dart';
import 'package:zerotv_player/features/subscription/application/manage_subscription.dart';
import 'package:zerotv_player/features/subscription/application/sync_subscription.dart';
import 'package:zerotv_player/features/subscription/data/drift_subscription_repository.dart';
import 'package:zerotv_player/features/subscription/data/subscription_source_factory.dart';

/// Provides the [SubscriptionRepository].
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return DriftSubscriptionRepository(ref.watch(appDatabaseProvider));
});

/// Watches all subscriptions.
final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchAll();
});

/// Provides the [ManageSubscription] use case.
final manageSubscriptionProvider = Provider<ManageSubscription>((ref) {
  return ManageSubscription(
    subscriptions: ref.watch(subscriptionRepositoryProvider),
  );
});

/// Shared dio client for subscription fetches.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'User-Agent': 'zeroTV/1.0.1'},
    ),
  );
  dio.interceptors.add(RetryInterceptor(dio));
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

/// Provides the [SubscriptionSourceFactory].
final sourceFactoryProvider = Provider<SubscriptionSourceFactory>((ref) {
  return DefaultSubscriptionSourceFactory(dio: ref.watch(dioProvider));
});

/// Provides the playlist parser (M3U for now, pluggable later).
final playlistParserProvider = Provider<PlaylistParser>((ref) {
  return const M3uPlaylistParser();
});

/// Provides the [SyncSubscription] use case.
final syncSubscriptionProvider = Provider<SyncSubscription>((ref) {
  return SyncSubscription(
    sources: ref.watch(sourceFactoryProvider),
    parser: ref.watch(playlistParserProvider),
    subscriptions: ref.watch(subscriptionRepositoryProvider),
    channels: ref.watch(channelRepositoryProvider),
    // Playlist-advertised EPG pointers are adopted only when the user
    // has no EPG source of their own (see adoptPlaylistEpgUrlProvider).
    adoptEpgUrl: ref.watch(adoptPlaylistEpgUrlProvider),
  );
});

/// Provides the [AddSubscription] use case.
final addSubscriptionProvider = Provider<AddSubscription>((ref) {
  return AddSubscription(
    subscriptions: ref.watch(subscriptionRepositoryProvider),
    channels: ref.watch(channelRepositoryProvider),
    parser: ref.watch(playlistParserProvider),
    sync: ref.watch(syncSubscriptionProvider),
  );
});

/// Provides the [AutoSyncService].
final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  return AutoSyncService(
    subscriptions: ref.watch(subscriptionRepositoryProvider),
    sync: ref.watch(syncSubscriptionProvider),
  );
});

/// App bootstrap: seeds the built-in default subscriptions on first
/// launch (a fast local operation), then fires the initial due-sync in
/// the background via [backgroundSyncControllerProvider]. Resolves as
/// soon as local state is ready so the UI can render cached channels
/// immediately instead of waiting on the network.
final bootstrapProvider = FutureProvider<void>((ref) async {
  await DefaultSourceSeeder(
    ref.watch(subscriptionRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
  ).seedIfNeeded();
  // Expired probe results would mislead the available view and failover;
  // purge them once per launch so the table stays bounded.
  await ref
      .watch(probeResultRepositoryProvider)
      .purgeStale(
        DateTime.now().subtract(ProbeResult.stalenessThreshold),
      );
  unawaited(ref.read(backgroundSyncControllerProvider.notifier).run());
});
