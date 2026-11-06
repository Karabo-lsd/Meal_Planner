import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/recipe.dart';
import 'package:meal_planning_app/core/recipe_filters.dart';

Recipe _recipe({
  String title = 'Recipe',
  List<String>? tags,
  List<String>? diets,
  List<String>? ingredients,
  String? mealType,
  int? prepTime,
  double? protein,
  double? carbs,
}) {
  return Recipe(
    id: title,
    title: title,
    tags: tags,
    supportedDiets: diets,
    ingredients: ingredients,
    mealType: mealType,
    prepTime: prepTime,
    protein: protein,
    carbs: carbs,
  );
}

void main() {
  group('RecipeFilters', () {
    test('matches meal types and common breakfast and lunch names', () {
      final breakfast = _recipe(title: 'Blueberry Pancakes');
      final lunch = _recipe(title: 'Avocado Sandwich');
      final dinner = _recipe(
        title: 'Roasted Vegetables',
        mealType: 'Main Course',
      );

      expect(RecipeFilters.matchesQuickFilter(breakfast, 'Breakfast'), isTrue);
      expect(RecipeFilters.matchesQuickFilter(lunch, 'Lunch'), isTrue);
      expect(RecipeFilters.matchesQuickFilter(dinner, 'Dinner'), isTrue);
    });

    test('uses supported diet labels and nutrition thresholds', () {
      final vegan = _recipe(diets: ['plant_based']);
      final proteinRich = _recipe(protein: 25);
      final keto = _recipe(carbs: 20);
      final notKeto = _recipe(carbs: 21);

      expect(RecipeFilters.matchesQuickFilter(vegan, 'Vegan'), isTrue);
      expect(
        RecipeFilters.matchesQuickFilter(proteinRich, 'High Protein'),
        isTrue,
      );
      expect(RecipeFilters.matchesQuickFilter(keto, 'Keto'), isTrue);
      expect(RecipeFilters.matchesQuickFilter(notKeto, 'Low Carb'), isFalse);
    });

    test(
      'missing nutrition does not classify a recipe as keto or low carb',
      () {
        final unknownNutrition = _recipe();

        expect(
          RecipeFilters.matchesQuickFilter(unknownNutrition, 'Keto'),
          isFalse,
        );
        expect(
          RecipeFilters.matchesQuickFilter(unknownNutrition, 'Low Carb'),
          isFalse,
        );
      },
    );

    test('quick meals require known short prep time or a supporting label', () {
      expect(
        RecipeFilters.matchesQuickFilter(_recipe(prepTime: 25), 'Quick Meals'),
        isTrue,
      );
      expect(
        RecipeFilters.matchesQuickFilter(_recipe(prepTime: 26), 'Quick Meals'),
        isFalse,
      );
      expect(
        RecipeFilters.matchesQuickFilter(_recipe(), 'Quick Meals'),
        isFalse,
      );
    });

    test('categories inspect titles, ingredients and meal labels', () {
      expect(
        RecipeFilters.matchesCategory(
          _recipe(title: 'Penne with Tomato', ingredients: ['basil']),
          'Pasta',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.matchesCategory(
          _recipe(title: 'Chocolate Cake'),
          'Desserts',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.matchesCategory(
          _recipe(title: 'Berry Smoothie'),
          'Drinks',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.matchesCategory(
          _recipe(title: 'Creamy Lasagna'),
          'Comfort Food',
        ),
        isTrue,
      );
    });

    test('recognizes explicit nutrition labels and common dish synonyms', () {
      expect(
        RecipeFilters.matchesQuickFilter(
          _recipe(diets: ['low_sodium']),
          'Healthy',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.matchesQuickFilter(
          _recipe(title: 'Mushroom Omelette'),
          'Breakfast',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.matchesCategory(
          _recipe(title: 'Spinach Ravioli'),
          'Pasta',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.matchesCategory(
          _recipe(title: 'Classic Mac & Cheese'),
          'Comfort Food',
        ),
        isTrue,
      );
    });

    test('combines quick filter and category rather than replacing either', () {
      final recipes = [
        _recipe(
          title: 'Quick Vegan Pasta',
          tags: ['quick'],
          diets: ['vegan'],
          ingredients: ['penne'],
          prepTime: 20,
        ),
        _recipe(
          title: 'Slow Vegan Pasta',
          diets: ['vegan'],
          ingredients: ['penne'],
          prepTime: 60,
        ),
        _recipe(
          title: 'Quick Chicken Pasta',
          tags: ['quick'],
          ingredients: ['penne', 'chicken'],
          prepTime: 20,
        ),
      ];

      expect(
        RecipeFilters.apply(
          recipes,
          quickFilter: 'Vegan',
          category: 'Pasta',
        ).map((recipe) => recipe.title),
        ['Quick Vegan Pasta', 'Slow Vegan Pasta'],
      );
    });
  });
}
