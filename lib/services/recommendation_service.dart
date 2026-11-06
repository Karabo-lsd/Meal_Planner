import 'package:dio/dio.dart';

import 'api_client.dart';

class RecommendationService {
  RecommendationService({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> recommend({
    required String userId,
    String requestType = 'dinner',
    String? query,
    int limit = 50,
    int page = 0,
    Map<String, dynamic> context = const {},
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/recommendations',
      data: {
        'user_id': userId,
        'request_type': requestType,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        'limit': limit,
        'page': page,
        'context': context,
      },
    );
    final recommendations = response.data?['recommendations'];
    if (recommendations is! List) {
      throw const FormatException(
        'The recommendations response did not contain a list.',
      );
    }
    return recommendations.map((item) {
      if (item is! Map) {
        throw const FormatException(
          'The recommendations response contained an invalid item.',
        );
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  /// Instructions, exact ingredient amounts and nutrition for a recipe.
  Future<Map<String, dynamic>> recipeDetails(String recipeId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/recipes/${Uri.encodeComponent(recipeId)}/details',
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  /// Grounded AI chat. Returns `{reply, recipes, source}`.
  Future<Map<String, dynamic>> chat({
    required String userId,
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/chat',
      data: {'user_id': userId, 'message': message, 'history': history},
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }

  /// Generates and stores a meal plan starting on [startDate] (a Monday by default).
  Future<Map<String, dynamic>> generateMealPlan({
    required String userId,
    required DateTime startDate,
    int days = 7,
    List<String> slots = const ['breakfast', 'lunch', 'dinner'],
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/meal-plans/generate',
      data: {
        'user_id': userId,
        'days': days,
        'slots': slots,
        'start_date': startDate.toIso8601String().split('T').first,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return Map<String, dynamic>.from(response.data ?? const {});
  }
}
