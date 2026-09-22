import 'package:iptv_core/src/entities/channel.dart';

/// Persistence port for channels belonging to subscriptions.
abstract interface class ChannelRepository {
  /// Watches channels of one subscription in source order.
  Stream<List<Channel>> watchBySubscription(String subscriptionId);

  /// Watches distinct group titles of one subscription.
  Stream<List<String>> watchGroups(String subscriptionId);

  /// Replaces all channels of [subscriptionId] with [channels].
  ///
  /// User data (favorites, history) lives in separate tables keyed by
  /// [Channel.identityKey], so replacement never destroys it.
  Future<void> replaceAll(String subscriptionId, List<Channel> channels);
}
