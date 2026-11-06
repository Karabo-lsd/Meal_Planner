import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

class ApiClient {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _SupabaseAuthInterceptor(dio),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: false,
          requestBody: false,
          responseBody: false,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      _FailoverInterceptor(dio, AppConfig.baseUrlCandidates),
      _RetryInterceptor(dio),
    ]);

    return dio;
  }
}

class _SupabaseAuthInterceptor extends Interceptor {
  _SupabaseAuthInterceptor(this.dio);

  static const _refreshAttemptedKey = 'authRefreshAttempted';

  final Dio dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra[_refreshAttemptedKey] == true) {
      handler.next(err);
      return;
    }

    request.extra[_refreshAttemptedKey] = true;
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (refreshError) {
      debugPrint('Supabase session refresh failed: $refreshError');
      handler.next(err);
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      handler.next(err);
      return;
    }

    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    try {
      handler.resolve(await dio.fetch(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}

/// When the current backend URL is unreachable (e.g. USB reverse not set up,
/// or not on the same Wi-Fi), tries the other candidates and keeps the one
/// that works for subsequent requests.
class _FailoverInterceptor extends Interceptor {
  _FailoverInterceptor(this.dio, this.candidates);

  static const _triedKey = 'failoverTried';
  static const _nestedKey = 'failoverNested';

  final Dio dio;
  final List<String> candidates;

  bool _isNetworkFailure(DioException err) =>
      err.response == null &&
      (err.type == DioExceptionType.connectionError ||
          err.type == DioExceptionType.connectionTimeout);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (candidates.length < 2 ||
        err.requestOptions.extra[_nestedKey] == true ||
        !_isNetworkFailure(err)) {
      handler.next(err);
      return;
    }

    final request = err.requestOptions;
    final tried = <String>{
      ...((request.extra[_triedKey] as List?)?.cast<String>() ?? const []),
      request.baseUrl,
    };
    request.extra[_triedKey] = tried.toList();

    for (final candidate in candidates) {
      if (tried.contains(candidate)) continue;
      request.baseUrl = candidate;
      request.extra[_nestedKey] = true;
      try {
        final response = await dio.fetch(request);
        dio.options.baseUrl = candidate;
        debugPrint('API backend switched to $candidate');
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        if (!_isNetworkFailure(retryError)) {
          dio.options.baseUrl = candidate;
          handler.next(retryError);
          return;
        }
        tried.add(candidate);
      }
    }
    handler.next(err);
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this.dio);

  final Dio dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final currentRetryCount =
        (err.requestOptions.extra['retryCount'] as int?) ?? 0;

    if (_shouldRetry(err) && currentRetryCount < AppConfig.maxRetries) {
      err.requestOptions.extra['retryCount'] = currentRetryCount + 1;
      await Future.delayed(Duration(seconds: currentRetryCount + 1));
      try {
        handler.resolve(await dio.fetch(err.requestOptions));
      } on DioException catch (retryError) {
        handler.next(retryError);
      }
      return;
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.connectionError ||
      (err.response?.statusCode ?? 0) >= 500;
}
