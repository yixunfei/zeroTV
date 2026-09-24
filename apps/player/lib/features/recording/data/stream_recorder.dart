import 'dart:async';
import 'dart:io';

/// A handle to an in-progress recording.
///
/// [done] completes when the stream ends or [stop] is called. [bytesWritten]
/// reflects the number of payload bytes written so far.
class RecordingHandle {
  RecordingHandle._({
    required IOSink sink,
    required Stream<List<int>> stream,
  }) : _sink = sink {
    _subscription = stream.listen(
      (chunk) {
        bytesWritten += chunk.length;
        _sink.add(chunk);
      },
      onDone: () async {
        await _sink.flush();
        await _sink.close();
        _stopped = true;
        if (!_done.isCompleted) _done.complete();
      },
      onError: (Object e, StackTrace s) async {
        await _sink.close();
        _stopped = true;
        if (!_done.isCompleted) _done.completeError(e, s);
      },
      cancelOnError: true,
    );
  }

  final IOSink _sink;
  final _done = Completer<void>();
  late final StreamSubscription<List<int>> _subscription;

  /// Completes when the recording has fully stopped.
  Future<void> get done => _done.future;

  /// Number of payload bytes written so far.
  int bytesWritten = 0;

  bool _stopped = false;

  /// Whether the recording is still running.
  bool get isActive => !_stopped;

  /// Stops the recording and closes the file.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _subscription.cancel();
    await _sink.flush();
    await _sink.close();
    if (!_done.isCompleted) _done.complete();
  }
}

/// Captures a live HTTP(S) stream to a local file, byte-for-byte (no
/// transcoding, no re-muxing).
///
/// This is a best-effort recorder: it writes the raw response body as it
/// arrives. Non-HTTP schemes (RTSP/UDP) are not supported.
class StreamRecorder {
  /// Creates a recorder. [client] is injectable for testing.
  StreamRecorder({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// Starts recording [url] into [filePath] with optional [headers].
  Future<RecordingHandle> start({
    required Uri url,
    required String filePath,
    Map<String, String> headers = const {},
  }) async {
    if (!(url.isScheme('HTTP') || url.isScheme('HTTPS'))) {
      throw UnsupportedError('仅支持 http(s) 流录制：$url');
    }
    final request = await _client.getUrl(url);
    headers.forEach(request.headers.set);
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw HttpException('录制请求失败：HTTP ${response.statusCode}', uri: url);
    }
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    return RecordingHandle._(sink: sink, stream: response);
  }

  /// Releases the underlying [HttpClient].
  void close() => _client.close(force: true);
}
