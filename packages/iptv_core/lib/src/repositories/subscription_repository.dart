import 'package:iptv_core/src/entities/subscription.dart';

/// Persistence port for user subscriptions.
abstract interface class SubscriptionRepository {
  /// Watches all subscriptions, ordered by creation time.
  Stream<List<Subscription>> watchAll();

  /// Returns all subscriptions once, ordered by creation time.
  Future<List<Subscription>> getAll();

  /// Inserts or updates [subscription].
  Future<void> upsert(Subscription subscription);

  /// Removes the subscription with [id] and all of its channels.
  Future<void> remove(String id);

  /// Records a successful sync time for [id].
  Future<void> markSynced(String id, DateTime syncedAt);

  /// Renames the subscription with [id] to [name].
  ///
  /// Targeted update: other fields (e.g. lastSyncedAt) are left
  /// untouched, so a concurrent sync cannot be clobbered.
  Future<void> rename(String id, String name);

  /// Enables or disables automatic sync for the subscription with [id].
  ///
  /// Disabling only stops future syncs; already stored channels stay
  /// visible until the subscription is removed.
  Future<void> setEnabled(String id, {required bool enabled});
}
