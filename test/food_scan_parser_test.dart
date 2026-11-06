import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/services/food_scan_service.dart';

void main() {
  group('FoodScanParser', () {
    test('parses nested nutrition payload safely', () {
      final parsed = FoodScanParser.parse({
        'meal_title': 'Kiwi Smoothie Bowl',
        'meal_type': 'Breakfast',
        'confidence': 0.83,
        'nutrition': {'calories': 450, 'protein': 20, 'carbs': 140, 'fat': 12},
        'foods': [
          {'name': 'Kiwi', 'calories': 50},
        ],
      });

      expect(parsed.mealTitle, 'Kiwi Smoothie Bowl');
      expect(parsed.calories, 450);
      expect(parsed.protein, 20);
      expect(parsed.carbs, 140);
      expect(parsed.fat, 12);
      expect(parsed.confidence, 0.83);
      expect(parsed.raw['foods'], hasLength(1));
    });

    test('merges fallback nutrition data', () {
      final parsed = FoodScanParser.parse({'meal_title': 'Meal'});
      final merged = FoodScanParser.mergeWithNutrition(parsed, {
        'kcal': 300,
        'protein': 18,
        'carbohydrates': 40,
        'fat': 9,
      });

      expect(merged.calories, 300);
      expect(merged.protein, 18);
      expect(merged.carbs, 40);
      expect(merged.fat, 9);
      expect(merged.raw.containsKey('nutrition_fallback'), isTrue);
    });
  });
}
