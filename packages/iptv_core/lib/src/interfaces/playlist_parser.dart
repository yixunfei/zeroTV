import 'package:iptv_core/src/entities/channel.dart';
import 'package:iptv_core/src/interfaces/subscription_source.dart';

/// A parsed playlist: channels plus an optional EPG pointer.
class ParsedPlaylist {
  /// Creates a parsed playlist.
  const ParsedPlaylist({required this.channels, this.epgUrl});

  /// All channels found in the playlist, in source order.
  final List<Channel> channels;

  /// EPG URL advertised by the playlist header (`x-tvg-url`), if any.
  final Uri? epgUrl;
}

/// Port for playlist format parsers (M3U, TXT group format, ...).
abstract interface class PlaylistParser {
  /// Parses [raw] into a [ParsedPlaylist]. Malformed entries are skipped,
  /// never fatal.
  ParsedPlaylist parse(RawPlaylist raw);
}
