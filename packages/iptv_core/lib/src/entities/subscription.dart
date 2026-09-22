/// Where a subscription's playlist content comes from.
enum SubscriptionKind {
  /// Fetched from a remote M3U URL.
  remoteUrl,

  /// Imported from a local file.
  localFile,

  /// Pasted directly as text by the user.
  pastedText,
}

/// A user-managed playlist subscription.
class Subscription {
  /// Creates a subscription.
  const Subscription({
    required this.id,
    required this.name,
    required this.kind,
    this.uri,
    this.refreshInterval = const Duration(hours: 6),
    this.enabled = true,
    this.lastSyncedAt,
  });

  /// Stable unique id (uuid).
  final String id;

  /// User-facing name.
  final String name;

  /// Origin kind of this subscription.
  final SubscriptionKind kind;

  /// Remote URL or local file path; null for [SubscriptionKind.pastedText].
  final String? uri;

  /// How often the subscription is re-fetched. Defaults to 6 hours,
  /// matching the upstream list update cadence.
  final Duration refreshInterval;

  /// Whether automatic sync is enabled for this subscription.
  final bool enabled;

  /// Last successful sync time; null if never synced.
  final DateTime? lastSyncedAt;

  /// Whether this subscription is due for a sync now.
  bool get isDue {
    final synced = lastSyncedAt;
    if (synced == null) return true;
    return DateTime.now().difference(synced) >= refreshInterval;
  }
}
