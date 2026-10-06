import 'package:iptv_core/iptv_core.dart';

/// Name of the implicit subscription that owns user-added channels.
///
/// This constant is a stable storage identifier, not display copy: the
/// subscriptions page renders it through l10n (`kindManual` label), so
/// an English user sees "Custom channels" instead of Chinese text.
/// Keep it unchanged so existing databases keep matching.
const manualSubscriptionName = '我的频道';

/// Stable id of the implicit manual subscription. A fixed id makes lazy
/// creation idempotent: two concurrent adds upsert the same row instead
/// of creating two manual subscriptions.
const manualSubscriptionId = 'manual';

/// Use case: append or replace one user-entered channel inside the
/// implicit "manual" subscription. The subscription is created lazily
/// on first use; it never syncs (it has no upstream URI).
class AddCustomChannel {
  /// Creates the use case.
  AddCustomChannel({
    required SubscriptionRepository subscriptions,
    required ChannelRepository channels,
  }) : _subscriptions = subscriptions,
       _channels = channels;

  final SubscriptionRepository _subscriptions;
  final ChannelRepository _channels;

  /// Adds (or replaces, when the identity key matches) one channel.
  Future<void> call(Channel channel) async {
    final sub = await _ensureManualSubscription();
    await _channels.upsertManual(sub.id, channel);
  }

  Future<Subscription> _ensureManualSubscription() async {
    final all = await _subscriptions.getAll();
    for (final s in all) {
      if (s.kind == SubscriptionKind.manual) return s;
    }
    const created = Subscription(
      id: manualSubscriptionId,
      name: manualSubscriptionName,
      kind: SubscriptionKind.manual,
      enabled: false,
    );
    await _subscriptions.upsert(created);
    return created;
  }
}
