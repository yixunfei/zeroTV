import 'package:iptv_core/src/entities/epg.dart';

/// Persistence port for EPG data.
abstract interface class EpgRepository {
  /// Returns programmes for [channelId] overlapping [from]-[to].
  Future<List<EpgProgram>> programmesFor(
    String channelId,
    DateTime from,
    DateTime to,
  );

  /// Returns every programme overlapping [from]-[to], across all channels,
  /// ordered by start time. Used to build now/next for a whole channel
  /// list without one query per channel.
  Future<List<EpgProgram>> programmesInWindow(DateTime from, DateTime to);

  /// Returns all EPG channel metadata, keyed by XMLTV channel id.
  Future<List<EpgChannel>> allChannels();

  /// Replaces the stored feed (channels + programmes).
  Future<void> replaceFeed(EpgFeed feed);

  /// Removes all stored EPG data.
  Future<void> clear();
}
