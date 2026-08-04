import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/ingredient.dart';
import 'package:meal_planning_app/core/models/recipe.dart';
import 'package:meal_planning_app/services/recommendation_engine.dart';

void main() {
  group('RecommendationEngine', () {
    test('filters by dietary preference and sorts by pantry match', () {
      final engine = RecommendationEngine();
      final recipes = [
        Recipe(
          id: '1',
          title: 'Keto Omelette',
          ingredients: const ['egg', 'cheese'],
          calories: 450,
          supportedDiets: const ['keto'],
        ),
        Recipe(
          id: '2',
          title: 'Protein Bowl',
          ingredients: const ['chicken', 'rice'],
          calories: 550,
          supportedDiets: const ['high_protein'],
        ),
      ];

      final pantry = [
        Ingredient(name: 'egg', custom: true),
        Ingredient(name: 'cheese', custom: true),
      ];

      final result = engine.rankAndFilter(
        recipes: recipes,
        pantry: pantry,
        dietaryPreference: 'keto',
        goals: const {},
      );

      expect(result.length, 1);
      expect(result.first.title, 'Keto Omelette');
    });

    test('respects daily calories goal', () {
      final engine = RecommendationEngine();
      final recipes = [
        Recipe(id: '1', title: 'Light Salad', calories: 350),
        Recipe(id: '2', title: 'Heavy Pasta', calories: 900),
      ];

      final result = engine.rankAndFilter(
        recipes: recipes,
        pantry: const [],
        dietaryPreference: null,
        goals: const {'daily_calories': 500},
      );

      expect(result.length, 1);
      expect(result.first.title, 'Light Salad');
    });
  });
}
