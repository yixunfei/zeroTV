import 'package:iptv_core/src/entities/epg.dart';

/// Port for EPG feed sources (remote XMLTV URL, local file, ...).
abstract interface class EpgProvider {
  /// Fetches and parses the feed at [uri].
  Future<EpgFeed> fetch(Uri uri);
}
