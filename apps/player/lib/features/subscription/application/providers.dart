import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:m3u_parser/m3u_parser.dart';
import 'package:zerotv_player/core/database/database_provider.dart';
import 'package:zerotv_player/core/preferences/shared_preferences_provider.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/subscription/application/add_subscription.dart';
import 'package:zerotv_player/features/subscription/application/auto_sync_service.dart';
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
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      headers: const {'User-Agent': 'zeroTV/0.1.0'},
    ),
  );
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

/// App bootstrap: seeds the built-in default subscription on first
/// launch, then syncs everything that is due. Resolves with the list of
/// per-subscription failures (empty means fully synced).
final bootstrapProvider = FutureProvider<List<SyncFailure>>((ref) async {
  await DefaultSourceSeeder(
    ref.watch(subscriptionRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
  ).seedIfNeeded();
  return ref.watch(autoSyncServiceProvider).syncDue();
});
