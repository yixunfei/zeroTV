import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/channel/application/add_custom_channel.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
import 'package:zerotv_player/features/channel/application/remove_custom_channel.dart';
import 'package:zerotv_player/features/subscription/application/providers.dart';

/// Provides the [AddCustomChannel] use case.
///
/// Lives outside [channel providers] to avoid import cycles with the
/// subscription providers it depends on.
final addCustomChannelProvider = Provider<AddCustomChannel>((ref) {
  return AddCustomChannel(
    subscriptions: ref.watch(subscriptionRepositoryProvider),
    channels: ref.watch(channelRepositoryProvider),
  );
});

/// Provides the [RemoveCustomChannel] use case.
final removeCustomChannelProvider = Provider<RemoveCustomChannel>((ref) {
  return RemoveCustomChannel(
    subscriptions: ref.watch(subscriptionRepositoryProvider),
    channels: ref.watch(channelRepositoryProvider),
  );
});

/// The manual ("my channels") subscription, or null when none exists.
final manualSubscriptionProvider = Provider<AsyncValue<Subscription?>>((ref) {
  return ref
      .watch(subscriptionsProvider)
      .whenData(
        (subs) =>
            subs.where((s) => s.kind == SubscriptionKind.manual).firstOrNull,
      );
});

/// Identity keys of every channel in the manual subscription.
final manualChannelKeysProvider = StreamProvider<Set<String>>((ref) {
  final manual = ref.watch(manualSubscriptionProvider).value;
  if (manual == null) return Stream.value(const <String>{});
  return ref
      .watch(channelRepositoryProvider)
      .watchBySubscription(manual.id)
      .map((channels) => {for (final c in channels) c.identityKey});
});
