import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/data/subscription_source_factory.dart';

/// Outcome of a successful subscription sync.
class SyncResult {
  /// Creates the result.
  const SyncResult({
    required this.subscriptionId,
    required this.channelCount,
    this.epgUrl,
  });

  /// The synced subscription.
  final String subscriptionId;

  /// Number of channels now stored.
  final int channelCount;

  /// EPG URL advertised by the playlist, if any.
  final Uri? epgUrl;
}

/// Use case: fetch a subscription's playlist, parse it, and atomically
/// replace its channels. On any failure the previously stored channels
/// are left untouched (fetch/parse happen before the replace).
class SyncSubscription {
  /// Creates the use case.
  SyncSubscription({
    required SubscriptionSourceFactory sources,
    required PlaylistParser parser,
    required SubscriptionRepository subscriptions,
    required ChannelRepository channels,
  }) : _sources = sources,
       _parser = parser,
       _subscriptions = subscriptions,
       _channels = channels;

  final SubscriptionSourceFactory _sources;
  final PlaylistParser _parser;
  final SubscriptionRepository _subscriptions;
  final ChannelRepository _channels;

  /// Syncs [subscription] and returns the result.
  Future<SyncResult> call(Subscription subscription) async {
    final raw = await _sources.forSubscription(subscription).fetch();
    final parsed = _parser.parse(raw);
    await _channels.replaceAll(subscription.id, parsed.channels);
    await _subscriptions.markSynced(subscription.id, DateTime.now());
    return SyncResult(
      subscriptionId: subscription.id,
      channelCount: parsed.channels.length,
      epgUrl: parsed.epgUrl,
    );
  }
}
