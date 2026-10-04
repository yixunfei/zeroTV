import 'package:iptv_core/iptv_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';

/// Seeds the curated built-in subscriptions, versioned by catalog.
///
/// A persisted version counter (not store emptiness) gates seeding, so a
/// user who deleted a built-in source never sees that source resurrected
/// on the next launch. When the catalog grows (version bump), only
/// sources introduced after the previously seeded version are added —
/// deletions the user made on older sources stay deleted.
class DefaultSourceSeeder {
  /// Creates the seeder.
  const DefaultSourceSeeder(this._subscriptions, this._prefs);

  /// Shared-preferences key recording the seeded catalog version.
  static const seededVersionKey = 'default_source_seeded_version';

  /// Legacy boolean key from the pre-versioning seeder.
  static const _legacySeededKey = 'default_source_seeded';

  final SubscriptionRepository _subscriptions;
  final SharedPreferences _prefs;

  /// The catalog version this device has already seeded (1 before
  /// versioning existed, 0 when seeding never ran).
  int get _seededVersion {
    final version = _prefs.getInt(seededVersionKey);
    if (version != null) return version;
    return (_prefs.getBool(_legacySeededKey) ?? false) ? 1 : 0;
  }

  /// Brings the built-in source catalogue up to
  /// [DefaultSubscription.catalogVersion]. Returns true when anything
  /// was inserted.
  Future<bool> seedIfNeeded() async {
    var seeded = _seededVersion;
    final existing = await _subscriptions.getAll();
    await _removeRetiredBuiltins(existing);
    final activeExisting = [
      for (final subscription in existing)
        if (!DefaultSubscription.retiredUris.contains(subscription.uri))
          subscription,
    ];
    if (activeExisting.isNotEmpty && seeded == 0) {
      // Legacy pre-seeder install that already has its own
      // subscriptions: keep the v1 built-ins absent (they opted out),
      // but still let newer catalogue additions arrive below.
      seeded = 1;
    }
    if (seeded >= DefaultSubscription.catalogVersion) return false;
    final existingUris = {for (final s in activeExisting) s.uri};
    var inserted = false;
    for (final source in DefaultSubscription.sources) {
      if (source.sinceVersion > DefaultSubscription.catalogVersion) continue;
      if (source.sinceVersion <= seeded) continue;
      // Skip when the user already added this source manually — under any
      // of its mirror URLs (it would otherwise show up twice).
      if (existingUris.any(source.owns)) continue;
      await _subscriptions.upsert(
        Subscription(
          id: const Uuid().v4(),
          name: source.name,
          kind: SubscriptionKind.remoteUrl,
          uri: source.candidates.first,
          channelGroupPrefix: source.channelGroupPrefix,
        ),
      );
      inserted = true;
    }
    await _prefs.setInt(
      seededVersionKey,
      DefaultSubscription.catalogVersion,
    );
    return inserted;
  }

  Future<void> _removeRetiredBuiltins(List<Subscription> existing) async {
    for (final subscription in existing) {
      if (DefaultSubscription.retiredUris.contains(subscription.uri)) {
        await _subscriptions.remove(subscription.id);
      }
    }
  }
}
