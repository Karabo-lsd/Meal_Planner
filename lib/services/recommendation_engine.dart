import '../core/models/ingredient.dart';
import '../core/models/recipe.dart';

class RecommendationEngine {
  List<Recipe> rankAndFilter({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
    required Map<String, dynamic> goals,
    String? dietaryPreference,
  }) {
    final pantrySet = pantry.map((e) => e.name.toLowerCase()).toSet();
    final targetCalories = (goals['daily_calories'] as num?)?.toInt();

    final filtered = recipes.where((recipe) {
      final dietOk = _matchesDiet(recipe, dietaryPreference);
      final calorieOk = targetCalories == null ||
          recipe.calories == null ||
          recipe.calories! <= targetCalories;
      return dietOk && calorieOk;
    }).toList();

    filtered.sort((a, b) {
      final aScore = _scoreRecipe(a, pantrySet);
      final bScore = _scoreRecipe(b, pantrySet);
      return bScore.compareTo(aScore);
    });

    return filtered;
  }

  bool _matchesDiet(Recipe recipe, String? dietaryPreference) {
    if (dietaryPreference == null || dietaryPreference.isEmpty) {
      return true;
    }
    final diets = recipe.supportedDiets ?? const [];
    return diets.map((e) => e.toLowerCase()).contains(dietaryPreference.toLowerCase());
  }

  int _scoreRecipe(Recipe recipe, Set<String> pantrySet) {
    final recipeIngredients =
        recipe.ingredients?.map((e) => e.toLowerCase()).toList() ?? const [];
    if (recipeIngredients.isEmpty) {
      return 0;
    }

    var matches = 0;
    for (final ingredient in recipeIngredients) {
      if (pantrySet.contains(ingredient)) {
        matches += 1;
      }
    }

    return (matches * 100) ~/ recipeIngredients.length;
  }
}
