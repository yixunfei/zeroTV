import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotv_player/features/channel/application/add_custom_channel.dart';
import 'package:zerotv_player/features/channel/application/providers.dart';
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
