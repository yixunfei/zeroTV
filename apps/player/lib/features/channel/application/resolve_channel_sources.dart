import 'package:iptv_core/iptv_core.dart';

/// Resolves the playable source list for one logical channel.
///
/// Several subscriptions may carry the same channel (same
/// [Channel.identityKey]); the player tries them in order until one
/// plays. The user's explicitly tapped source always comes first; if a
/// different source was recently probed as [ProbeStatus.ok] it is
/// promoted to second, so a dead first source fails over quickly.
class ResolveChannelSources {
  /// Creates the resolver.
  const ResolveChannelSources();

  /// Returns the ordered, de-duplicated source list for [channel].
  ///
  /// [allChannels] is the full channel table; [probes] maps identity keys
  /// to their latest availability result.
  List<Channel> call(
    Channel channel,
    List<Channel> allChannels,
    Map<String, ProbeResult> probes,
  ) {
    final key = channel.identityKey;
    final seen = <String>{};
    final ordered = <Channel>[];
    void add(Channel c) {
      if (seen.add(c.streamUrl)) ordered.add(c);
    }

    add(channel);
    for (final c in allChannels) {
      if (c.identityKey == key) add(c);
    }
    if (ordered.length <= 1) return ordered;

    final probe = probes[key];
    if (probe == null || probe.status != ProbeStatus.ok) return ordered;

    final index = ordered.indexWhere((c) => c.streamUrl == probe.url);
    if (index <= 0) return ordered;

    return [
      ordered.first,
      ordered[index],
      for (var i = 1; i < ordered.length; i++)
        if (i != index) ordered[i],
    ];
  }
}
