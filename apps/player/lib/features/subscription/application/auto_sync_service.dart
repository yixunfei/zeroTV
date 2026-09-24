import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/application/sync_subscription.dart';

/// A single subscription that failed during an auto-sync pass.
class SyncFailure {
  /// Creates the failure record.
  const SyncFailure(this.subscriptionId, this.error);

  /// The failed subscription.
  final String subscriptionId;

  /// Diagnostic message.
  final String error;
}

/// Syncs every enabled subscription whose refresh interval has elapsed.
/// Individual failures are collected and returned, never thrown, and
/// never destroy previously synced data.
class AutoSyncService {
  /// Creates the service.
  AutoSyncService({
    required SubscriptionRepository subscriptions,
    required SyncSubscription sync,
  }) : _subscriptions = subscriptions,
       _sync = sync;

  final SubscriptionRepository _subscriptions;
  final SyncSubscription _sync;

  /// Syncs all due subscriptions; returns the failures (empty on success).
  ///
  /// When [intervalOverride] is provided, it replaces each subscription's
  /// own refresh interval for the due check (used by the user's global
  /// "sync interval" setting).
  Future<List<SyncFailure>> syncDue({Duration? intervalOverride}) async {
    final subs = await _subscriptions.getAll();
    final failures = <SyncFailure>[];
    for (final s in subs) {
      if (!s.enabled || !_isDue(s, intervalOverride)) continue;
      try {
        await _sync(s);
      } on Object catch (e) {
        failures.add(SyncFailure(s.id, '$e'));
      }
    }
    return failures;
  }

  bool _isDue(Subscription s, Duration? override) {
    if (override == null) return s.isDue;
    final synced = s.lastSyncedAt;
    if (synced == null) return true;
    return DateTime.now().difference(synced) >= override;
  }
}
