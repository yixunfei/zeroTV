/// Where a subscription's playlist content comes from.
enum SubscriptionKind {
  /// Fetched from a remote M3U URL.
  remoteUrl,

  /// Imported from a local file.
  localFile,

  /// Pasted directly as text by the user.
  pastedText,

  /// Curated one channel at a time by the user; no wholesale sync.
  manual,
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
    this.channelGroupPrefix,
  });

  /// Stable unique id (uuid).
  final String id;

  /// User-facing name.
  final String name;

  /// Origin kind of this subscription.
  final SubscriptionKind kind;

  /// Remote URL or local file path; null for [SubscriptionKind.pastedText]
  /// and [SubscriptionKind.manual].
  final String? uri;

  /// How often the subscription is re-fetched. Defaults to 6 hours,
  /// matching the upstream list update cadence.
  final Duration refreshInterval;

  /// Whether automatic sync is enabled for this subscription.
  final bool enabled;

  /// Last successful sync time; null if never synced.
  final DateTime? lastSyncedAt;

  /// Optional prefix prepended to every channel group of this
  /// subscription (`"<prefix> · <original group>"`), grouping the
  /// subscription's channels into their own section of the group
  /// switcher. Null means the original playlist groups are kept as-is.
  final String? channelGroupPrefix;

  /// Whether this subscription is due for a sync now.
  bool get isDue {
    final synced = lastSyncedAt;
    if (synced == null) return true;
    return DateTime.now().difference(synced) >= refreshInterval;
  }
}
