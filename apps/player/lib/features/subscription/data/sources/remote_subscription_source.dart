import 'dart:async';

import 'package:dio/dio.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/core/text/content_encoding.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

/// Fetches playlist content from remote URLs.
///
/// All mirror candidates are requested concurrently and the first
/// non-empty response wins (losers are cancelled), so one unreachable
/// or slow mirror adds zero latency instead of a full serial timeout.
class RemoteSubscriptionSource implements SubscriptionSource {
  /// Creates the source. [candidates] must be non-empty.
  RemoteSubscriptionSource({
    required List<Uri> candidates,
    required Dio dio,
    this.timeout = const Duration(seconds: 20),
  }) : assert(candidates.isNotEmpty, 'candidates must not be empty'),
       _candidates = candidates,
       _dio = dio;

  final List<Uri> _candidates;
  final Dio _dio;

  /// Per-request receive timeout.
  final Duration timeout;

  @override
  Future<RawPlaylist> fetch() {
    if (_candidates.length == 1) {
      return _fetchOne(_candidates.single, null);
    }
    final completer = Completer<RawPlaylist>();
    final tokens = [for (final _ in _candidates) CancelToken()];
    var pending = _candidates.length;
    Object? lastError;
    for (var i = 0; i < _candidates.length; i++) {
      unawaited(
        _fetchOne(_candidates[i], tokens[i])
            .then((playlist) {
              if (completer.isCompleted) return;
              completer.complete(playlist);
              for (var j = 0; j < tokens.length; j++) {
                if (j != i) tokens[j].cancel('a faster mirror responded');
              }
            })
            .onError((e, _) {
              lastError = e;
              pending--;
              if (pending == 0 && !completer.isCompleted) {
                completer.completeError(
                  SubscriptionFetchException('所有候选地址均不可达：$lastError'),
                );
              }
            }),
      );
    }
    return completer.future;
  }

  Future<RawPlaylist> _fetchOne(Uri uri, CancelToken? cancelToken) async {
    // Fetch raw bytes and decode here: playlists are frequently
    // GBK-encoded with no charset header, which dio's default UTF-8
    // decoding would turn into replacement-character soup.
    final res = await _dio.getUri<List<int>>(
      uri,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: timeout,
      ),
    );
    final data = res.data;
    if (data == null || data.isEmpty) {
      throw SubscriptionFetchException('empty body ($uri)');
    }
    final content = decodeTextContent(data);
    // Validate the body looks like an M3U playlist before accepting it:
    // a mirror may "win" the race with an HTML error/interstitial page.
    final looksLikePlaylist =
        content.startsWith('#EXTM3U') || content.contains('#EXTINF');
    if (!looksLikePlaylist) {
      throw SubscriptionFetchException('not a playlist ($uri)');
    }
    return RawPlaylist(content: content, originUri: uri);
  }
}
