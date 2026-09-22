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
}
