import 'package:iptv_core/iptv_core.dart';

/// Use case: remove one user-added channel from the "my channels" list.
///
/// A no-op when the channel does not belong to the manual subscription,
/// so callers need not check membership first.
class RemoveCustomChannel {
  /// Creates the use case.
  RemoveCustomChannel({
    required SubscriptionRepository subscriptions,
    required ChannelRepository channels,
  }) : _subscriptions = subscriptions,
       _channels = channels;

  final SubscriptionRepository _subscriptions;
  final ChannelRepository _channels;

  /// Deletes [identityKey] from the manual subscription, if present.
  Future<void> call(String identityKey) async {
    final all = await _subscriptions.getAll();
    for (final s in all) {
      if (s.kind == SubscriptionKind.manual) {
        await _channels.deleteManual(s.id, identityKey);
        return;
      }
    }
  }
}
