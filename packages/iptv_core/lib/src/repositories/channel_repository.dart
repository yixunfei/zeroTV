import 'package:iptv_core/src/entities/channel.dart';

/// Group label used for channels without a `group-title`.
const ungroupedGroupLabel = '未分组';

/// Persistence port for channels belonging to subscriptions.
abstract interface class ChannelRepository {
  /// Watches channels of one subscription in source order.
  Stream<List<Channel>> watchBySubscription(String subscriptionId);

  /// Watches channels across all subscriptions, in source order.
  Stream<List<Channel>> watchAll();

  /// Watches distinct group titles of one subscription.
  Stream<List<String>> watchGroups(String subscriptionId);

  /// Watches distinct group titles across all subscriptions.
  Stream<List<String>> watchAllGroups();

  /// Replaces all channels of [subscriptionId] with [channels].
  ///
  /// User data (favorites, history) lives in separate tables keyed by
  /// [Channel.identityKey], so replacement never destroys it.
  Future<void> replaceAll(String subscriptionId, List<Channel> channels);

  /// Inserts or replaces one channel of [subscriptionId], matched by
  /// [Channel.identityKey]. Used by the manual "my channels" list where
  /// [replaceAll] would be too coarse.
  Future<void> upsertManual(String subscriptionId, Channel channel);

  /// Deletes one channel of [subscriptionId] by [Channel.identityKey].
  Future<void> deleteManual(String subscriptionId, String identityKey);

  /// Watches the number of stored channels per subscription, keyed by
  /// subscription id. Subscriptions without channels are absent.
  Stream<Map<String, int>> watchCountsBySubscription();
}
