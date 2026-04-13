import 'dart:io';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../core/config/app_config.dart';
import 'api_client.dart';

class MealService {
  final _supabase = Supabase.instance.client;
  final Dio _dio = ApiClient.instance;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── ML image analysis (Python backend) ───────────────────
  // This stays on the Python backend — Supabase has no vision API.

  Future<Map<String, dynamic>> analyzeMealImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'meal_image.jpg',
        ),
      });
      final response = await _dio.post(
        AppConfig.analyzeMeal,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ── food_logs CRUD (Supabase) ─────────────────────────────

  Future<List<Map<String, dynamic>>> getLogs({
    DateTime? date,
    String? mealSlot,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('food_logs')
        .select('*, foods_master(canonical_name), recipes(title)')
        .eq('user_id', _userId);

    if (date != null) {
      query = query.eq('log_date', date.toIso8601String().split('T')[0]);
    }
    if (mealSlot != null) {
      query = query.eq('meal_slot', mealSlot);
    }

    return List<Map<String, dynamic>>.from(
      await query.order('log_date', ascending: false).limit(limit),
    );
  }

  // Backward-compat alias used by existing screens
  Future<List<Map<String, dynamic>>> getMeals({
    int skip = 0,
    int limit = 20,
  }) =>
      getLogs(limit: limit);

  Future<Map<String, dynamic>> logFood({
    required String mealSlot,
    String? canonicalFoodId,
    String? recipeId,
    required String source,
    DateTime? date,
    double? quantity,
    String? unit,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    bool estimationFlag = false,
  }) async {
    assert(canonicalFoodId != null || recipeId != null,
        'Either canonicalFoodId or recipeId must be provided');
    return await _supabase
        .from('food_logs')
        .insert({
          'user_id': _userId,
          'log_date': (date ?? DateTime.now()).toIso8601String().split('T')[0],
          'meal_slot': mealSlot,
          if (canonicalFoodId != null) 'canonical_food_id': canonicalFoodId,
          if (recipeId != null) 'recipe_id': recipeId,
          'source': source,
          if (quantity != null) 'quantity': quantity,
          if (unit != null) 'unit': unit,
          if (calories != null) 'calories': calories,
          if (protein != null) 'protein': protein,
          if (carbs != null) 'carbs': carbs,
          if (fat != null) 'fat': fat,
          'estimation_flag': estimationFlag,
        })
        .select()
        .single();
  }

  // Backward-compat wrapper for food_scan_service
  Future<Map<String, dynamic>> logMeal({
    required String mealType,
    String? imageUrl,
    bool manualEntry = false,
    Map<String, dynamic>? analysisResult,
  }) =>
      logFood(
        mealSlot: mealType,
        source: manualEntry ? 'manual' : 'image_scan',
        calories: (analysisResult?['calories'] as num?)?.toDouble(),
        protein: (analysisResult?['protein'] as num?)?.toDouble(),
        carbs: (analysisResult?['carbs'] as num?)?.toDouble(),
        fat: (analysisResult?['fat'] as num?)?.toDouble(),
        estimationFlag: true,
        // food_logs requires one of canonicalFoodId/recipeId — use a placeholder
        // until a canonical food is resolved
        canonicalFoodId: analysisResult?['canonical_food_id'] as String?,
        recipeId: analysisResult?['recipe_id'] as String?,
      );

  Future<Map<String, dynamic>> updateLog(
      String logId, Map<String, dynamic> data) async {
    return await _supabase
        .from('food_logs')
        .update(data)
        .eq('id', logId)
        .select()
        .single();
  }

  // Legacy int-id overload kept for old screen calls
  Future<Map<String, dynamic>> getMealById(dynamic mealId) async {
    return await _supabase
        .from('food_logs')
        .select()
        .eq('id', mealId.toString())
        .single();
  }

  Future<void> deleteLog(String logId) async {
    await _supabase.from('food_logs').delete().eq('id', logId);
  }

  Future<void> deleteMeal(dynamic mealId) => deleteLog(mealId.toString());

  // ── Helpers ───────────────────────────────────────────────

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return Exception(data['detail'] as String);
      }
      return Exception('Server error: ${e.response!.statusCode}');
    }
    return Exception('Network error: ${e.message}');
  }
}