import 'dart:async';

import 'package:iptv_core/iptv_core.dart';

/// In-memory [ScheduledRecordingRepository] for tests.
class FakeScheduledRecordingRepository implements ScheduledRecordingRepository {
  /// Creates the fake with optional initial rows.
  FakeScheduledRecordingRepository([List<ScheduledRecording>? initial])
    : _items = [...?initial];

  final List<ScheduledRecording> _items;
  final _changes = StreamController<List<ScheduledRecording>>.broadcast();

  /// Returns the row with [id], for assertions on state transitions.
  ScheduledRecording byId(String id) => _items.firstWhere((s) => s.id == id);

  /// Number of rows currently stored.
  int get length => _items.length;

  @override
  Stream<List<ScheduledRecording>> watchAll() async* {
    yield List.unmodifiable(_sorted());
    yield* _changes.stream;
  }

  @override
  Future<void> upsert(ScheduledRecording scheduled) async {
    final i = _items.indexWhere((s) => s.id == scheduled.id);
    if (i >= 0) {
      _items[i] = scheduled;
    } else {
      _items.insert(0, scheduled);
    }
    _notify();
  }

  @override
  Future<void> markState(String id, ScheduledRecordingState state) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = _items[i].withState(state);
    _notify();
  }

  @override
  Future<void> remove(String id) async {
    _items.removeWhere((s) => s.id == id);
    _notify();
  }

  List<ScheduledRecording> _sorted() =>
      [..._items]..sort((a, b) => b.startAt.compareTo(a.startAt));

  void _notify() => _changes.add(List.unmodifiable(_sorted()));
}
