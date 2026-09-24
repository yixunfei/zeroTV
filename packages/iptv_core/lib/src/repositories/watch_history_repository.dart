import 'package:iptv_core/src/entities/history_entry.dart';

/// Persistence port for watch history.
///
/// Entries are keyed by channel identity key (tvgId when present,
/// otherwise normalized name) so they survive wholesale channel
/// replacement on sync — same contract as favorites.
abstract interface class WatchHistoryRepository {
  /// Appends a watch record.
  Future<void> record(HistoryEntry entry);

  /// Watches the most recent entries, one per channel, ordered by
  /// latest watch time descending. [limit] caps the result size.
  Stream<List<HistoryEntry>> watchRecent({int limit = 50});
}
