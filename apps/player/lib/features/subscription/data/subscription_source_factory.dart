import 'package:dio/dio.dart';
import 'package:iptv_core/iptv_core.dart';
import 'package:zerotv_player/features/subscription/data/sources/file_subscription_source.dart';
import 'package:zerotv_player/features/subscription/data/sources/remote_subscription_source.dart';
import 'package:zerotv_player/features/subscription/domain/default_subscription.dart';

/// Builds the right [SubscriptionSource] for a given [Subscription].
abstract interface class SubscriptionSourceFactory {
  /// Returns the source for [subscription].
  ///
  /// Throws [UnsupportedError] for kinds that cannot be re-fetched
  /// (pasted text is a one-shot import).
  SubscriptionSource forSubscription(Subscription subscription);
}

/// Default factory: remote via dio (with default-source mirror fallback),
/// local file, pasted text unsupported.
class DefaultSubscriptionSourceFactory implements SubscriptionSourceFactory {
  /// Creates the factory.
  DefaultSubscriptionSourceFactory({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  SubscriptionSource forSubscription(Subscription subscription) {
    switch (subscription.kind) {
      case SubscriptionKind.remoteUrl:
        return RemoteSubscriptionSource(
          candidates: _candidatesFor(subscription.uri),
          dio: _dio,
        );
      case SubscriptionKind.localFile:
        final path = subscription.uri;
        if (path == null) {
          throw ArgumentError('localFile subscription requires a uri');
        }
        return FileSubscriptionSource(path);
      case SubscriptionKind.pastedText:
        throw UnsupportedError('粘贴文本订阅不支持重新同步');
    }
  }

  List<Uri> _candidatesFor(String? uri) {
    if (DefaultSubscription.isDefaultUri(uri)) {
      return [for (final u in DefaultSubscription.candidates) Uri.parse(u)];
    }
    if (uri == null) {
      throw ArgumentError('remoteUrl subscription requires a uri');
    }
    return [Uri.parse(uri)];
  }
}
