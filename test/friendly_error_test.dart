import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/friendly_error.dart';

void main() {
  test('connection errors hide hosts and ports', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/x', baseUrl: 'http://10.3.8.19:8000'),
      type: DioExceptionType.connectionError,
      message: 'No route to host, port = 8000',
    );
    final message = friendlyErrorMessage(error, action: 'load recipes');
    expect(message, contains('not available right now'));
    expect(message, isNot(contains('8000')));
    expect(message, isNot(contains('10.3.8.19')));
  });

  test('unknown errors never leak exception text', () {
    final message = friendlyErrorMessage(
      Exception('relation "x" does not exist'),
      action: 'save this',
    );
    expect(message, 'We could not save this right now. Please try again.');
  });
}
