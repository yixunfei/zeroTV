import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iptv_core/iptv_core.dart';

/// Serializes source changes and preserves errors received during open().
class PlaybackSession extends ChangeNotifier {
  /// Creates a session with the selected source first.
  PlaybackSession({
    required this.sources,
    required Future<void> Function(Channel) open,
  }) : _open = open;

  /// Ordered sources for this logical channel.
  final List<Channel> sources;
  final Future<void> Function(Channel) _open;
  bool _disposed = false;
  bool _opening = false;
  String? _pendingError;
  int? _pendingSwitch;

  // media_kit forwards cplayer error-level log lines, not only fatal failures.
  // Android surface attachment seeks to the current position, which live
  // streams may reject even while their video and audio continue playing.
  static final _seekDiagnostic = RegExp(
    r'^(cannot seek in this stream\.?|'
    r"you can force it with '?--force-seekable=yes'?\.?)$",
    caseSensitive: false,
  );

  /// Current source index.
  int index = 0;

  /// Terminal playback error, cleared on successful playback.
  String? error;

  /// While true, asynchronous errors are surfaced as terminal errors
  /// without advancing to the next source. Used during catchup playback,
  /// which bypasses the session's source list: a catchup stream failure
  /// must not kick the user back to the live failover chain.
  bool _suspended = false;

  /// Suspends source failover (see [_suspended]).
  void suspendFailover() => _suspended = true;

  /// Resumes source failover after [suspendFailover].
  void resumeFailover() => _suspended = false;

  /// Whether a source is being opened.
  bool get opening => _opening;

  /// Current endpoint.
  Channel get current => sources[index];

  /// Opens the first source, continuing through synchronous failures.
  Future<void> start() => _openSources();

  /// Restarts playback from the first source after a terminal error.
  /// Ignored while an open is in progress or when there is no error.
  void retry() {
    if (_disposed || _opening || error == null) return;
    index = 0;
    error = null;
    unawaited(_openSources());
  }

  /// Manually switches to the source at [newIndex] (user picked it from
  /// the source list). A switch requested while another open is in
  /// progress is queued and applied once that open settles. Ignored when
  /// the index is out of range. Selecting the current source after a
  /// terminal error restarts it.
  void switchTo(int newIndex) {
    if (_disposed) return;
    if (newIndex < 0 || newIndex >= sources.length) return;
    if (_opening) {
      _pendingSwitch = newIndex;
      return;
    }
    if (newIndex == index) {
      if (error == null) return;
      error = null;
      unawaited(_openSources());
      return;
    }
    index = newIndex;
    unawaited(_openSources());
  }

  /// Accepts asynchronous errors, including those emitted during open().
  void onError(String message) {
    final failure = message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !_seekDiagnostic.hasMatch(line))
        .join('\n');
    if (_disposed || failure.isEmpty) return;
    if (_suspended) {
      error = failure;
      notifyListeners();
      return;
    }
    if (_opening) {
      _pendingError = failure;
      return;
    }
    if (index + 1 < sources.length) {
      index++;
      unawaited(_openSources());
    } else {
      error = failure;
      notifyListeners();
    }
  }

  /// Removes stale error overlays after the player recovers.
  void onPlaying() {
    if (_disposed || error == null) return;
    error = null;
    notifyListeners();
  }

  Future<void> _openSources() async {
    if (_disposed || _opening) return;
    _opening = true;
    error = null;
    notifyListeners();
    while (!_disposed) {
      _pendingError = null;
      try {
        await _open(current);
      } on Object catch (e) {
        _pendingError = '$e';
      }
      if (_disposed) return;
      // Failover was suspended (catchup started) while we were opening:
      // stop advancing so we do not override the catchup stream.
      if (_suspended) break;
      final failure = _pendingError;
      if (failure == null) break;
      if (index + 1 == sources.length) {
        error = failure;
        break;
      }
      index++;
    }
    _opening = false;
    if (!_disposed) notifyListeners();
    final pendingSwitch = _pendingSwitch;
    _pendingSwitch = null;
    if (pendingSwitch != null && !_disposed && pendingSwitch < sources.length) {
      if (pendingSwitch != index || error != null) {
        index = pendingSwitch;
        unawaited(_openSources());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
