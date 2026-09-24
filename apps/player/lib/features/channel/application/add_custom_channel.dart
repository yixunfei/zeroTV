import 'package:iptv_core/iptv_core.dart';
import 'package:uuid/uuid.dart';

/// Name of the implicit subscription that owns user-added channels.
const manualSubscriptionName = '我的频道';

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
    final created = Subscription(
      id: const Uuid().v4(),
      name: manualSubscriptionName,
      kind: SubscriptionKind.manual,
      enabled: false,
    );
    await _subscriptions.upsert(created);
    return created;
  }
}
