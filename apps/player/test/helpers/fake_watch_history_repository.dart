import 'dart:async';

import 'package:iptv_core/iptv_core.dart';

/// In-memory [WatchHistoryRepository] for widget and use-case tests:
/// reactive (records re-emit), no drift, no pending timers.
class FakeWatchHistoryRepository implements WatchHistoryRepository {
  /// Creates the fake with optional initial entries.
  FakeWatchHistoryRepository([List<HistoryEntry>? initial])
    : _entries = [...?initial];

  final List<HistoryEntry> _entries;
  final _changes = StreamController<List<HistoryEntry>>.broadcast();

  @override
  Future<void> record(HistoryEntry entry) async {
    _entries.add(entry);
    _changes.add(List.unmodifiable(_entries));
  }

  @override
  Stream<List<HistoryEntry>> watchRecent({int limit = 50}) async* {
    yield _recent(limit);
    yield* _changes.stream.map((_) => _recent(limit));
  }

  List<HistoryEntry> _recent(int limit) {
    final latest = <String, HistoryEntry>{};
    for (final e in _entries) {
      final current = latest[e.channelKey];
      if (current == null || e.watchedAt.isAfter(current.watchedAt)) {
        latest[e.channelKey] = e;
      }
    }
    final sorted = latest.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return sorted.take(limit).toList();
  }
}
