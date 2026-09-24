import 'dart:async';

import 'package:iptv_core/iptv_core.dart';

/// In-memory [RecordingRepository] for tests.
class FakeRecordingRepository implements RecordingRepository {
  /// Creates the fake with optional initial rows.
  FakeRecordingRepository([List<Recording>? initial])
    : _recordings = [...?initial];

  final List<Recording> _recordings;
  final _changes = StreamController<List<Recording>>.broadcast();

  /// The last recording passed to [upsert].
  Recording? saved;

  /// Id passed to the last [finish] call.
  String? finishedId;

  /// Size passed to the last [finish] call.
  int? finishedSize;

  /// Id passed to the last [remove] call.
  String? removedId;

  @override
  Stream<List<Recording>> watchAll() async* {
    yield List.unmodifiable(_recordings);
    yield* _changes.stream;
  }

  @override
  Future<void> upsert(Recording recording) async {
    saved = recording;
    final i = _recordings.indexWhere((r) => r.id == recording.id);
    if (i >= 0) {
      _recordings[i] = recording;
    } else {
      _recordings.insert(0, recording);
    }
    _notify();
  }

  @override
  Future<void> finish(String id, DateTime endedAt, int sizeBytes) async {
    finishedId = id;
    finishedSize = sizeBytes;
    final i = _recordings.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _recordings[i];
    _recordings[i] = Recording(
      id: r.id,
      channelKey: r.channelKey,
      channelName: r.channelName,
      filePath: r.filePath,
      startedAt: r.startedAt,
      endedAt: endedAt,
      sizeBytes: sizeBytes,
    );
    _notify();
  }

  @override
  Future<void> remove(String id) async {
    removedId = id;
    _recordings.removeWhere((r) => r.id == id);
    _notify();
  }

  void _notify() => _changes.add(List.unmodifiable(_recordings));
}
