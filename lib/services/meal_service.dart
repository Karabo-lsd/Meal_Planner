import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class MealService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── ML image analysis (Supabase Edge Function) ────────────

  Future<Map<String, dynamic>> analyzeMealImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : 'meal_image.jpg';

    try {
      final response = await _supabase.functions.invoke(
        'analyze-meal-image',
        body: {
          'user_id': _userId,
          'filename': filename,
          'image_base64': base64Encode(bytes),
        },
      );

      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return payload;
      }

      // Some function handlers return { data: {...} }.
      if (payload is Map && payload['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(payload['data'] as Map);
      }
    } catch (_) {
      // Fall through to catalog-only fallback.
    }

    return _fallbackAnalyzeFromCatalog(filename);
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

  Future<Map<String, dynamic>> _fallbackAnalyzeFromCatalog(
      String filename) async {
    final guess = filename
        .toLowerCase()
        .replaceAll(RegExp(r'\.[a-z0-9]+$'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

    final tokens = guess
        .split(' ')
        .where((t) => t.length >= 3)
        .toList(growable: false);

    for (final token in tokens.take(5)) {
      final rows = await _supabase
          .from('foods_master')
          .select('id, canonical_name, food_nutrition(*)')
          .ilike('canonical_name', '%$token%')
          .limit(1);

      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) continue;

      final food = list.first;
      final nutrition =
          (food['food_nutrition'] as Map<String, dynamic>?) ?? const {};

      return {
        'meal_title': food['canonical_name'] ?? 'Scanned Meal',
        'meal_type': 'Meal',
        'confidence': 0.45,
        'canonical_food_id': food['id'],
        'calories': (nutrition['per_100g_calories'] as num?)?.round() ?? 0,
        'protein': (nutrition['per_100g_protein'] as num?)?.toDouble() ?? 0,
        'carbs': (nutrition['per_100g_carbs'] as num?)?.toDouble() ?? 0,
        'fat': (nutrition['per_100g_fat'] as num?)?.toDouble() ?? 0,
        'source': 'supabase_catalog_fallback',
      };
    }

    return {
      'meal_title': 'Scanned Meal',
      'meal_type': 'Meal',
      'confidence': 0.2,
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'source': 'supabase_catalog_fallback',
    };
  }
}