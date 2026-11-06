import 'package:dio/dio.dart';

/// Converts any error into a short message that is safe to show to users.
/// Never exposes hosts, ports, status codes or exception text.
String friendlyErrorMessage(Object error, {String action = 'complete that'}) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Your session expired. Please sign in again.';
    if (status == 403) return 'You do not have access to do that.';
    if (status == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (status != null && status >= 500) {
      return 'This service is not available right now. Please try again later.';
    }
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Service not available right now. Please check your connection and try again.',
      _ => 'We could not $action right now. Please try again.',
    };
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('socketexception') ||
      raw.contains('clientexception') ||
      raw.contains('connection') ||
      raw.contains('host lookup') ||
      raw.contains('timed out') ||
      raw.contains('timeout') ||
      raw.contains('handshake') ||
      raw.contains('no route')) {
    return 'Service not available right now. Please check your connection and try again.';
  }
  return 'We could not $action right now. Please try again.';
}
