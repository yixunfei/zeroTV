import 'package:iptv_core/src/entities/epg.dart';

/// Persistence port for EPG data.
abstract interface class EpgRepository {
  /// Returns programmes for [channelId] overlapping [from]-[to].
  Future<List<EpgProgram>> programmesFor(
    String channelId,
    DateTime from,
    DateTime to,
  );

  /// Replaces the stored feed (channels + programmes).
  Future<void> replaceFeed(EpgFeed feed);
}
