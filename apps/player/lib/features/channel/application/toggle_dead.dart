import 'package:iptv_core/iptv_core.dart';

/// Use case: mark a channel as dead (or revive it).
///
/// Marks are keyed by [Channel.identityKey], so a channel that comes
/// back to life upstream is still hidden until the user revives it or
/// the mark is cleaned up.
class ToggleDead {
  /// Creates the use case.
  const ToggleDead({required DeadChannelRepository dead}) : _dead = dead;

  final DeadChannelRepository _dead;

  /// Marks [channel] as dead when it currently is not, otherwise
  /// revives it. [currentlyDead] must reflect the latest mark set.
  Future<void> call(Channel channel, {required bool currentlyDead}) {
    if (currentlyDead) {
      return _dead.unmark(channel.identityKey);
    }
    return _dead.mark(
      DeadChannel(
        channelKey: channel.identityKey,
        channelName: channel.name,
        streamUrl: channel.streamUrl,
        markedAt: DateTime.now(),
      ),
    );
  }
}
