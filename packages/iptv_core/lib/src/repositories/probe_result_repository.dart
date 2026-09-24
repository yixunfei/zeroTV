import 'package:iptv_core/src/entities/probe_result.dart';

/// Persistence port for stream availability probe results.
///
/// Results are keyed by channel identity key (tvgId when present,
/// otherwise normalized name) so they survive wholesale channel
/// replacement on sync — same contract as favorites/history.
abstract interface class ProbeResultRepository {
  /// Watches the latest probe result for every channel, keyed by
  /// channel identity key.
  Stream<Map<String, ProbeResult>> watchAll();

  /// Stores or replaces the result for [channelKey].
  Future<void> save(String channelKey, ProbeResult result);

  /// Clears all stored probe results.
  Future<void> clear();
}
