import 'package:iptv_core/src/entities/dead_channel.dart';

/// Persistence port for channels the user marked as dead/unplayable.
abstract interface class DeadChannelRepository {
  /// Watches the identity keys of all dead-marked channels.
  Stream<Set<String>> watchKeys();

  /// Watches all dead-marked channels, latest first.
  Stream<List<DeadChannel>> watchAll();

  /// Marks a channel as dead.
  Future<void> mark(DeadChannel entry);

  /// Removes the dead mark for [channelKey] (channel revived or user
  /// changed their mind).
  Future<void> unmark(String channelKey);

  /// Removes every dead mark whose channel no longer exists in the
  /// channel table (orphan cleanup).
  Future<void> clearOrphans(Set<String> existingKeys);
}
