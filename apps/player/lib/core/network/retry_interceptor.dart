import 'dart:async';

import 'package:dio/dio.dart';

/// Retries transient idempotent playlist and EPG requests with a short backoff.
/// The request body is never retried, so this interceptor remains safe for
/// the GET-only network clients used by the app.
class RetryInterceptor extends Interceptor {
  /// Creates an interceptor attached to [Dio].
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  final Dio _dio;

  /// Maximum number of retries after the initial request.
  final int maxRetries;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    if (request.method.toUpperCase() != 'GET' || !_isTransient(err)) {
      handler.next(err);
      return;
    }
    final attempt = (request.extra['_retryAttempt'] as int?) ?? 0;
    if (attempt >= maxRetries || request.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }
    request.extra['_retryAttempt'] = attempt + 1;
    unawaited(_retry(request, handler, attempt));
  }

  Future<void> _retry(
    RequestOptions request,
    ErrorInterceptorHandler handler,
    int attempt,
  ) async {
    try {
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      if (request.cancelToken?.isCancelled == true) {
        handler.next(
          DioException.requestCancelled(
            requestOptions: request,
            reason: 'request cancelled during retry backoff',
          ),
        );
        return;
      }
      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (error) {
      handler.next(error);
    } on Object catch (error, stack) {
      handler.next(
        DioException(
          requestOptions: request,
          error: error,
          stackTrace: stack,
        ),
      );
    }
  }

  bool _isTransient(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = error.response?.statusCode;
    return status == 408 || status == 429 || (status != null && status >= 500);
  }
}
