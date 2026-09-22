import 'package:iptv_core/iptv_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';

/// Seeds the built-in default subscription exactly once, on first launch.
///
/// A persisted flag (not store emptiness) gates seeding, so a user who
/// deleted the default source never sees it resurrected on the next
/// launch. Existing installs with any subscription are marked as seeded
/// without inserting anything.
class DefaultSourceSeeder {
  /// Creates the seeder.
  const DefaultSourceSeeder(this._subscriptions, this._prefs);

  /// Shared-preferences key recording that seeding already ran.
  static const seededKey = 'default_source_seeded';

  final SubscriptionRepository _subscriptions;
  final SharedPreferences _prefs;

  /// Inserts the default subscription when seeding never ran and the
  /// store is empty. Returns true when seeding happened.
  Future<bool> seedIfNeeded() async {
    if (_prefs.getBool(seededKey) ?? false) return false;
    final existing = await _subscriptions.getAll();
    if (existing.isNotEmpty) {
      await _prefs.setBool(seededKey, true);
      return false;
    }
    await _subscriptions.upsert(
      Subscription(
        id: const Uuid().v4(),
        name: DefaultSubscription.name,
        kind: SubscriptionKind.remoteUrl,
        uri: DefaultSubscription.candidates.first,
      ),
    );
    await _prefs.setBool(seededKey, true);
    return true;
  }
}
