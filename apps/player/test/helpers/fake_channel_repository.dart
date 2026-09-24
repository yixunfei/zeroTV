import 'package:iptv_core/iptv_core.dart';

/// In-memory [ChannelRepository] for widget tests: no drift, no native
/// libraries, no pending timers. Filtering logic in providers still runs
/// for real (providers re-map these static streams).
class FakeChannelRepository implements ChannelRepository {
  /// Creates the fake with fixed data.
  FakeChannelRepository({
    this.channels = const [],
    this.groups = const [],
    this.counts = const {},
  });

  /// Channels returned by all watch methods.
  final List<Channel> channels;

  /// Group titles returned by all group watch methods.
  final List<String> groups;

  /// Channel counts per subscription id.
  final Map<String, int> counts;

  @override
  Stream<List<Channel>> watchAll() => Stream.value(channels);

  @override
  Stream<List<Channel>> watchBySubscription(String subscriptionId) {
    return Stream.value(channels);
  }

  @override
  Stream<List<String>> watchGroups(String subscriptionId) {
    return Stream.value(groups);
  }

  @override
  Stream<List<String>> watchAllGroups() => Stream.value(groups);

  @override
  Stream<Map<String, int>> watchCountsBySubscription() {
    return Stream.value(counts);
  }

  @override
  Future<void> replaceAll(
    String subscriptionId,
    List<Channel> channels,
  ) async {}

  @override
  Future<void> upsertManual(String subscriptionId, Channel channel) async {}

  @override
  Future<void> deleteManual(String subscriptionId, String identityKey) async {}
}
