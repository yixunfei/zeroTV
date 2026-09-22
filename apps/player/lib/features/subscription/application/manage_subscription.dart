import 'package:iptv_core/iptv_core.dart';

/// Use case: manage an existing subscription — rename, enable/disable
/// auto-sync, or remove it (channels cascade; favorites and watch
/// history live in separate tables and survive removal).
class ManageSubscription {
  /// Creates the use case.
  ManageSubscription({required SubscriptionRepository subscriptions})
    : _subscriptions = subscriptions;

  final SubscriptionRepository _subscriptions;

  /// Renames the subscription. Blank names are rejected.
  Future<void> rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return _subscriptions.rename(id, trimmed);
  }

  /// Enables or disables automatic sync. Stored channels stay visible
  /// either way; disabling only stops future syncs.
  Future<void> setEnabled(String id, {required bool enabled}) {
    return _subscriptions.setEnabled(id, enabled: enabled);
  }

  /// Removes the subscription and its channels.
  Future<void> remove(String id) => _subscriptions.remove(id);
}
