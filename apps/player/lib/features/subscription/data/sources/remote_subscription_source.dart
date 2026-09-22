import 'package:dio/dio.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/domain/sync_exception.dart';

/// Fetches playlist content from remote URLs, trying candidates in order
/// (mirror fallback for unreliable networks).
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
  Future<RawPlaylist> fetch() async {
    Object? lastError;
    for (final uri in _candidates) {
      try {
        final res = await _dio.getUri<String>(
          uri,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: timeout,
          ),
        );
        final data = res.data;
        if (data != null && data.trim().isNotEmpty) {
          return RawPlaylist(content: data, originUri: uri);
        }
        lastError = 'empty body ($uri)';
      } on DioException catch (e) {
        lastError = e;
      }
    }
    throw SubscriptionFetchException('所有候选地址均不可达：$lastError');
  }
}
