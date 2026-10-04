import 'dart:async';
import 'dart:io';

/// A capture whose completion includes flushing and closing its output file.
class RecordingHandle {
  RecordingHandle._({required IOSink sink, required Stream<List<int>> stream})
    : _sink = sink {
    unawaited(_sink.done.then<void>((_) {}, onError: _onError));
    _subscription = stream.listen(
      (chunk) {
        bytesWritten += chunk.length;
        _sink.add(chunk);
      },
      onDone: () => unawaited(_finish()),
      onError: _onError,
      cancelOnError: true,
    );
    _done.future.ignore();
  }

  final IOSink _sink;
  final _done = Completer<void>();
  late final StreamSubscription<List<int>> _subscription;
  Future<void>? _finishing;
  Object? _error;
  StackTrace? _stack;

  /// Completes when capture has ended; reports network or disk failures.
  Future<void> get done => _done.future;

  /// Payload bytes received so far.
  int bytesWritten = 0;

  /// Whether capture is still accepting bytes.
  bool get isActive => _finishing == null;

  void _onError(Object error, StackTrace stack) {
    _error ??= error;
    _stack ??= stack;
    unawaited(_finish());
  }

  Future<void> _finish() => _finishing ??= _close();

  Future<void> _close() async {
    try {
      await _subscription.cancel();
      await _sink.flush();
    } on Object catch (error, stack) {
      _error ??= error;
      _stack ??= stack;
    } finally {
      try {
        await _sink.close();
      } on Object catch (error, stack) {
        _error ??= error;
        _stack ??= stack;
      }
      if (_error == null) {
        _done.complete();
      } else {
        _done.completeError(_error!, _stack);
      }
    }
  }

  /// Idempotently stops capture and awaits all output cleanup.
  Future<void> stop() async {
    await _finish();
    await done;
  }
}

/// Records direct HTTP media streams without transcoding or remuxing.
/// Playlist/HTML responses are rejected rather than saved as fake video.
class StreamRecorder {
  /// Creates a recorder with an optional HTTP client and connection deadline.
  StreamRecorder({
    HttpClient? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// Deadline for opening a stream (capture itself may run indefinitely).
  final Duration timeout;

  /// Starts recording a direct stream into [filePath].
  Future<RecordingHandle> start({
    required Uri url,
    required String filePath,
    Map<String, String> headers = const {},
  }) async {
    if (!(url.isScheme('HTTP') || url.isScheme('HTTPS'))) {
      throw UnsupportedError('仅支持 HTTP(S) 直连媒体流录制');
    }
    if (RegExp(r'\.(m3u8?|mpd)$', caseSensitive: false).hasMatch(url.path)) {
      throw UnsupportedError('暂不支持 HLS/DASH 分片流录制');
    }
    final request = await _client.getUrl(url).timeout(timeout);
    try {
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('录制请求失败：HTTP ${response.statusCode}', uri: url);
      }
      final type = response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (type.startsWith('text/') ||
          type.contains('mpegurl') ||
          type.contains('dash+xml') ||
          type.contains('json')) {
        throw UnsupportedError('响应不是可直接录制的媒体流：$type');
      }
      final file = File(filePath);
      await file.parent.create(recursive: true);
      return RecordingHandle._(sink: file.openWrite(), stream: response);
    } on Object {
      request.abort();
      rethrow;
    }
  }

  /// Releases the HTTP client and active connections.
  void close() => _client.close(force: true);
}
