import 'package:iptv_core/iptv_core.dart';
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';

/// Seeds the built-in default subscription on first launch
/// (i.e. when the store has no subscriptions at all).
class DefaultSourceSeeder {
  /// Creates the seeder.
  const DefaultSourceSeeder(this._subscriptions);

  final SubscriptionRepository _subscriptions;

  /// Inserts the default subscription if the store is empty.
  /// Returns true when seeding happened.
  Future<bool> seedIfEmpty() async {
    final existing = await _subscriptions.getAll();
    if (existing.isNotEmpty) return false;
    await _subscriptions.upsert(
      Subscription(
        id: const Uuid().v4(),
        name: DefaultSubscription.name,
        kind: SubscriptionKind.remoteUrl,
        uri: DefaultSubscription.candidates.first,
      ),
    );
    return true;
  }
}
