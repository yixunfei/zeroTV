/// Failure to fetch or store a subscription's playlist.
class SubscriptionFetchException implements Exception {
  /// Creates the exception.
  const SubscriptionFetchException(this.message);

  /// Human-readable diagnostic.
  final String message;

  @override
  String toString() => 'SubscriptionFetchException: $message';
}
