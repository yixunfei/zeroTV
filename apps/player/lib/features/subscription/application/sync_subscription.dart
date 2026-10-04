import 'dart:isolate';

import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/data/subscription_source_factory.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

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
///
/// For built-in sources with ad filtering enabled, entries whose
/// name/group matches promotion keywords (see
/// [DefaultSubscription.adKeywords]) are dropped, and when the
/// subscription carries a [Subscription.channelGroupPrefix] every
/// channel group is renamed into that prefix's section.
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
    // Parse on a worker isolate: large playlists (10k+ entries) would
    // otherwise jank the UI while a sync runs in the background. Only
    // locals are captured so nothing unsendable crosses isolates.
    final parser = _parser;
    final parsed = await Isolate.run(() => parser.parse(raw));
    if (parsed.channels.isEmpty) {
      throw const SubscriptionFetchException('订阅中没有有效频道，已保留原有数据');
    }
    final cleaned = cleanChannels(subscription, parsed.channels);
    if (cleaned.isEmpty) {
      throw const SubscriptionFetchException('订阅中没有有效频道，已保留原有数据');
    }
    await _channels.replaceAll(subscription.id, cleaned);
    await _subscriptions.markSynced(subscription.id, DateTime.now());
    return SyncResult(
      subscriptionId: subscription.id,
      channelCount: cleaned.length,
      epgUrl: parsed.epgUrl,
    );
  }

  /// Drops ad/promotion entries and applies the subscription's channel
  /// group prefix. Public so one-shot imports (pasted text) filter
  /// exactly like a regular sync.
  List<Channel> cleanChannels(
    Subscription subscription,
    List<Channel> channels,
  ) {
    // The group prefix applies only to curated built-in sources. The ad
    // keyword filter runs for every subscription, except built-ins that
    // explicitly opt out (global catalogues like iptv-org keep their
    // upstream entries untouched).
    final builtin = DefaultSubscription.sourceFor(subscription.uri);
    final prefix = builtin?.channelGroupPrefix;
    final filterAds = builtin?.filterAds ?? true;
    return [
      for (final c in channels)
        if (!filterAds || !_isAd(c))
          prefix == null ? c : _withGroupPrefix(c, prefix),
    ];
  }

  bool _isAd(Channel channel) {
    return DefaultSubscription.isAdChannel(channel.name) ||
        DefaultSubscription.isAdChannel(channel.groupTitle ?? '');
  }

  Channel _withGroupPrefix(Channel channel, String prefix) {
    final group = channel.groupTitle;
    return Channel(
      name: channel.name,
      streamUrl: channel.streamUrl,
      tvgId: channel.tvgId,
      tvgName: channel.tvgName,
      logoUrl: channel.logoUrl,
      groupTitle: group == null || group.isEmpty ? prefix : '$prefix · $group',
      catchupSource: channel.catchupSource,
      catchupDays: channel.catchupDays,
      userAgent: channel.userAgent,
      referrer: channel.referrer,
    );
  }
}
