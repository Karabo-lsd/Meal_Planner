import 'dart:io';

import '../core/models/food_scan_result.dart';
import 'ingredient_service.dart';
import 'meal_service.dart';

abstract class FoodRecognitionEngine {
  Future<FoodScanResult> analyzeMealImage(String imagePath);
}

class FoodScanService implements FoodRecognitionEngine {
  FoodScanService({
    required MealService mealService,
    required IngredientService ingredientService,
  })  : _mealService = mealService,
        _ingredientService = ingredientService;

  final MealService _mealService;
  final IngredientService _ingredientService;

  @override
  Future<FoodScanResult> analyzeMealImage(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('Selected image does not exist.');
    }

    final response = await _mealService.analyzeMealImage(file);
    var parsed = FoodScanParser.parse(response);

    // Fallback to ingredient database when AI has low confidence or missing macros.
    final shouldFallback = parsed.confidence < 0.5 ||
        parsed.calories <= 0 ||
        (parsed.protein + parsed.carbs + parsed.fat) <= 0;

    if (shouldFallback) {
      try {
        final nutrition = await _ingredientService.getIngredientNutrition(
          parsed.mealTitle,
          amount: 1,
          unit: 'serving',
        );

        parsed = FoodScanParser.mergeWithNutrition(parsed, nutrition);
      } catch (_) {
        // Keep AI output if nutrition lookup fails.
      }
    }

    return parsed;
  }
}

class FoodScanParser {
  static FoodScanResult parse(Map<String, dynamic> json) {
    final nutrition = _asMap(json['nutrition']);
    final macros = _asMap(json['macros']);

    final calories = _numAsInt(
      nutrition['calories'] ?? macros['calories'] ?? json['calories'],
    );

    final protein = _numAsDouble(
      nutrition['protein'] ?? macros['protein'] ?? json['protein'],
    );
    final carbs = _numAsDouble(
      nutrition['carbs'] ?? nutrition['carbohydrates'] ?? macros['carbs'] ?? json['carbs'],
    );
    final fat = _numAsDouble(
      nutrition['fat'] ?? macros['fat'] ?? json['fat'],
    );

    final mealTitle = (json['meal_title'] ??
            json['meal_name'] ??
            json['title'] ??
            json['detected_food'] ??
            'Scanned Meal')
        .toString();

    final mealType = (json['meal_type'] ?? json['category'] ?? 'Meal').toString();
    final confidence = _numAsDouble(json['confidence'] ?? json['score'] ?? 0.55);

    return FoodScanResult(
      mealTitle: mealTitle,
      mealType: mealType,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      confidence: confidence.clamp(0, 1).toDouble(),
      raw: json,
    );
  }

  static FoodScanResult mergeWithNutrition(
    FoodScanResult current,
    Map<String, dynamic> nutrition,
  ) {
    final calories = _numAsInt(
      nutrition['calories'] ?? nutrition['kcal'] ?? current.calories,
    );
    final protein = _numAsDouble(nutrition['protein'] ?? current.protein);
    final carbs = _numAsDouble(
      nutrition['carbs'] ?? nutrition['carbohydrates'] ?? current.carbs,
    );
    final fat = _numAsDouble(nutrition['fat'] ?? current.fat);

    return current.copyWith(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      raw: {...current.raw, 'nutrition_fallback': nutrition},
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return const {};
  }

  static int _numAsInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? (double.tryParse(value)?.round() ?? 0);
    }
    return 0;
  }

  static double _numAsDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }
}
