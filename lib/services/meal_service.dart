import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

class MealService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Authenticated food image analysis ─────────────────────

  Future<Map<String, dynamic>> analyzeMealImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 5 MB.');
    }

    final mediaType = _imageMediaType(bytes);
    final response = await ApiClient.instance.    post<Map<String, dynamic>>(
          '/api/food/analyze-image',
      data: {
        'media_type': mediaType,
        // Encoding a multi-MB photo off the UI thread avoids a visible hitch.
        'image_base64': await compute(base64Encode, bytes),
      },
    );
    final payload = response.data;
    if (payload == null) {
      throw StateError('Food recognition returned an empty response.');
    }
    return payload;
  }

  static String _imageMediaType(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    throw const FormatException(
      'Use a JPEG, PNG, or WebP image for food recognition.',
    );
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
  Future<List<Map<String, dynamic>>> getMeals({int skip = 0, int limit = 20}) =>
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
    String? foodName,
    int? usdaFdcId,
    double? confidenceScore,
    bool estimationFlag = false,
  }) async {
    assert(
      canonicalFoodId != null || recipeId != null || foodName != null,
      'A canonical food, recipe, or food name must be provided',
    );
    final values = <String, dynamic>{
      'user_id': _userId,
      'log_date': (date ?? DateTime.now()).toIso8601String().split('T')[0],
      'meal_slot': mealSlot,
      'source': source,
      'estimation_flag': estimationFlag,
    };
    if (canonicalFoodId != null) values['canonical_food_id'] = canonicalFoodId;
    if (recipeId != null) values['recipe_id'] = recipeId;
    if (quantity != null) values['quantity'] = quantity;
    if (unit != null) values['unit'] = unit;
    if (calories != null) values['calories'] = calories;
    if (protein != null) values['protein'] = protein;
    if (carbs != null) values['carbs'] = carbs;
    if (fat != null) values['fat'] = fat;
    if (foodName != null) values['food_name'] = foodName;
    if (usdaFdcId != null) values['usda_fdc_id'] = usdaFdcId;
    if (confidenceScore != null) values['confidence_score'] = confidenceScore;

    return await _supabase.from('food_logs').insert(values).select().single();
  }

  Future<List<Map<String, dynamic>>> logMeal({
    required String mealType,
    bool manualEntry = false,
    Map<String, dynamic>? analysisResult,
  }) async {
    final rawFoods = analysisResult?['foods'];
    if (rawFoods is! List || rawFoods.isEmpty) {
      throw StateError('Food recognition did not return any foods to save.');
    }
    final foods = rawFoods.whereType<Map>().toList();
    if (foods.length != rawFoods.length) {
      throw StateError('Food recognition returned invalid food details.');
    }

    final requestedSlot = mealType.toLowerCase();
    const mealSlots = {'breakfast', 'lunch', 'dinner', 'snack'};
    final mealSlot = mealSlots.contains(requestedSlot) ? requestedSlot : 'snack';
    final servings =
        (analysisResult?['servings'] as num?)?.toDouble() ?? 1;
    final source = manualEntry ? 'manual' : 'image_scan';
    final nutrientAdjustments = <String, double>{};
    for (final nutrient in ['calories', 'protein', 'carbs', 'fat']) {
      final requestedTotal = (analysisResult?[nutrient] as num?)?.toDouble();
      final foodTotal = foods.fold<double>(0, (total, food) {
        return total + ((food[nutrient] as num?)?.toDouble() ?? 0);
      });
      if (requestedTotal != null && foodTotal > 0) {
        nutrientAdjustments[nutrient] =
            requestedTotal / (foodTotal * servings);
      }
    }

    final logDate = DateTime.now().toIso8601String().split('T')[0];
    final rows = foods.map((food) {
        final name = food['name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          throw StateError('Food recognition returned a food without a name.');
        }

        double? scaledValue(String key) {
          final value = (food[key] as num?)?.toDouble();
          return value == null
              ? null
              : value * servings * (nutrientAdjustments[key] ?? 1);
        }

        final grams = (food['estimated_grams'] as num?)?.toDouble();
        final fdcId = (food['fdc_id'] as num?)?.toInt();
        final confidence = (food['confidence'] as num?)?.toDouble();
        final row = <String, dynamic>{
          'user_id': _userId,
          'log_date': logDate,
          'meal_slot': mealSlot,
          'source': source,
          'food_name': name,
          'estimation_flag': true,
        };
        if (fdcId != null) row['usda_fdc_id'] = fdcId;
        if (grams != null) {
          row['quantity'] = grams * servings;
          row['unit'] = 'g';
        }
        if (confidence != null) row['confidence_score'] = confidence;
        for (final nutrient in ['calories', 'protein', 'carbs', 'fat']) {
          final value = scaledValue(nutrient);
          if (value != null) row[nutrient] = value;
        }
        return row;
      }).toList();

    return List<Map<String, dynamic>>.from(
      await _supabase.from('food_logs').insert(rows).select(),
    );
  }

  Future<Map<String, dynamic>> updateLog(
    String logId,
    Map<String, dynamic> data,
  ) async {
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
}
