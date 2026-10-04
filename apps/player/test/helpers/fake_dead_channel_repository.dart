import 'package:iptv_core/iptv_core.dart';

/// In-memory [DeadChannelRepository] for widget and use-case tests:
/// no drift, no pending timers.
class FakeDeadChannelRepository implements DeadChannelRepository {
  /// Creates the fake with optional initial keys.
  FakeDeadChannelRepository([Set<String>? initial])
    : _keys = {...?initial},
      _entries = [
        for (final key in initial ?? const <String>{})
          DeadChannel(
            channelKey: key,
            channelName: key,
            streamUrl: 'http://fake/$key',
            markedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
      ];

  final Set<String> _keys;
  final List<DeadChannel> _entries;

  @override
  Stream<Set<String>> watchKeys() => Stream.value(_keys);

  @override
  Stream<List<DeadChannel>> watchAll() => Stream.value(List.of(_entries));

  @override
  Future<void> mark(DeadChannel entry) async {
    _keys.add(entry.channelKey);
    _entries.add(entry);
  }

  @override
  Future<void> unmark(String channelKey) async {
    _keys.remove(channelKey);
    _entries.removeWhere((e) => e.channelKey == channelKey);
  }

  @override
  Future<void> clearOrphans(Set<String> existingKeys) async {
    _keys.removeWhere((k) => !existingKeys.contains(k));
    _entries.removeWhere((e) => !existingKeys.contains(e.channelKey));
  }
}
