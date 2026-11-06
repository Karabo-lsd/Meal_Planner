import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/recipe.dart';

void main() {
  test('saved recipe JSON keeps homepage image and recipe data', () {
    final recipe = Recipe.fromJson({
      'id': 'recipe-1',
      'title': 'Lentil bowl',
      'image_url': 'https://example.com/lentil-bowl.jpg',
      'source_provider': 'spoonacular',
      'ingredients': ['1 cup lentils'],
      'steps': ['Cook the lentils.'],
      'recipe_nutrition': [
        {'calories': 420, 'protein': 24, 'carbs': 58, 'fat': 9},
      ],
    });

    expect(recipe.imageUrl, 'https://example.com/lentil-bowl.jpg');
    expect(recipe.sourceProvider, 'spoonacular');
    expect(recipe.ingredients, ['1 cup lentils']);
    expect(recipe.steps, ['Cook the lentils.']);
    expect(recipe.calories, 420);
    expect(recipe.protein, 24);
  });
}
