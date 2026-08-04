import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'spoonacular_service.dart';

class RecipeService {
  final _spoonacular = SpoonacularService();
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Catalog ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecipes({
    int skip = 0,
    int limit = 20,
    String? search,
    List<String>? tags,
    String? difficulty,
    int? maxCalories,
    int? maxPrepTime,
  }) async {
    try {
      var query = _supabase
          .from('recipes')
          .select('*, recipe_nutrition(*)');

      if (search != null && search.isNotEmpty) {
        query = query.ilike('title', '%$search%');
      }
      if (maxPrepTime != null) {
        query = query.lte('prep_time_minutes', maxPrepTime);
      }

      final result =
          await query.order('title').range(skip, skip + limit - 1);
      return List<Map<String, dynamic>>.from(result);
    } catch (_) {
      return _mockRecipes;
    }
  }

  Future<Map<String, dynamic>> getRecipeById(dynamic recipeId) async {
    return await _supabase
        .from('recipes')
        .select(
            '*, recipe_nutrition(*), recipe_ingredients(*, foods_master(canonical_name))')
        .eq('id', recipeId.toString())
        .single();
  }

  Future<List<Map<String, dynamic>>> getRecommendedRecipes(
      {int limit = 10}) async {
    // 1. Spoonacular — real recipes with images and nutrition
    try {
      final rows = await _spoonacular.searchRecipes(number: limit);
      if (rows.isNotEmpty) return rows;
      debugPrint('RecipeService: Spoonacular returned 0 recipes; falling back.');
    } catch (e) {
      debugPrint('RecipeService: Spoonacular failed: $e');
    }

    // 2. Supabase catalog
    try {
      final rows = await _supabase
          .from('recipes')
          .select('*, recipe_nutrition(*)')
          .order('created_at', ascending: false)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty) return list;
      debugPrint('RecipeService: Supabase recipes returned 0 rows; using mock fallback.');
    } catch (e) {
      debugPrint('RecipeService: Supabase recipes fallback failed: $e');
    }

    // 3. Static fallback
    return _mockRecipes.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getRecipesByIngredients(
    List<String> ingredients, {
    int limit = 20,
  }) async {
    try {
      // Find recipes whose ingredients overlap with the given list
      final rows = await _supabase
          .from('recipe_ingredients')
          .select('recipe_id, ingredient_name_normalized')
          .inFilter(
              'ingredient_name_normalized',
              ingredients.map((e) => e.toLowerCase().trim()).toList());

      final recipeIds = (rows as List)
          .map((r) => r['recipe_id'] as String)
          .toSet()
          .take(limit)
          .toList();

      if (recipeIds.isEmpty) return [];

      final recipes = await _supabase
          .from('recipes')
          .select('*, recipe_nutrition(*)')
          .inFilter('id', recipeIds);

      return List<Map<String, dynamic>>.from(recipes);
    } catch (_) {
      return _mockRecipes.take(limit).toList();
    }
  }

  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    required List<String> ingredients,
    required Map<String, dynamic> goals,
    String? dietaryPreference,
    int limit = 20,
  }) async {
    // 1. Spoonacular with pantry ingredients and diet preference
    try {
      final rows = await _spoonacular.searchRecipes(
        number: limit,
        diet: dietaryPreference,
        includeIngredients: ingredients.isEmpty ? null : ingredients,
      );
      if (rows.isNotEmpty) return rows;
      debugPrint('RecipeService: Spoonacular personalized returned 0 recipes; falling back.');
    } catch (e) {
      debugPrint('RecipeService: Spoonacular personalized failed: $e');
    }

    // 2. Fall back to popular recipes (Spoonacular without filters → Supabase → mocks)
    return getRecommendedRecipes(limit: limit);
  }

  // ── Saved recipes ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSavedRecipes({
    int skip = 0,
    int limit = 20,
  }) async {
    final rows = await _supabase
        .from('saved_recipes')
        .select('*, recipes(*, recipe_nutrition(*))')
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .range(skip, skip + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveRecipe(dynamic recipeId) async {
    await _supabase.from('saved_recipes').upsert({
      'user_id': _userId,
      'recipe_id': recipeId.toString(),
    });
  }

  Future<void> unsaveRecipe(dynamic recipeId) async {
    await _supabase
        .from('saved_recipes')
        .delete()
        .eq('user_id', _userId)
        .eq('recipe_id', recipeId.toString());
  }

  Future<bool> isRecipeSaved(dynamic recipeId) async {
    final row = await _supabase
        .from('saved_recipes')
        .select('id')
        .eq('user_id', _userId)
        .eq('recipe_id', recipeId.toString())
        .maybeSingle();
    return row != null;
  }

  // Backward-compat: old screens call toggleRecipeSave(id)
  Future<void> toggleRecipeSave(dynamic recipeId) async {
    final saved = await isRecipeSaved(recipeId);
    saved ? await unsaveRecipe(recipeId) : await saveRecipe(recipeId);
  }

  // Kept for screens that still call saveRecipe with a full map
  Future<Map<String, dynamic>> saveRecipeData(
      Map<String, dynamic> recipeData) async {
    final id = recipeData['id'];
    await saveRecipe(id);
    return recipeData;
  }

  Future<List<String>> getRecipeTags() async {
    // Return common dietary tags from the foods catalog
    return const [
      'vegetarian',
      'vegan',
      'gluten-free',
      'dairy-free',
      'high-protein',
      'low-carb',
      'keto',
    ];
  }

  // ── Fallback mock data ────────────────────────────────────

  static const List<Map<String, dynamic>> _mockRecipes = [
    {
      'id': 'mock-9001',
      'title': 'Power Breakfast Bowl',
      'summary': 'Greek yogurt, berries, oats, and chia seeds.',
      'image_url': 'https://loremflickr.com/640/480/breakfast?lock=9001',
      'ingredients': ['Greek yogurt', 'Berries', 'Oats', 'Chia seeds'],
      'recipe_nutrition': {
        'calories': 420.0,
        'protein': 28.0,
        'carbs': 44.0,
        'fat': 12.0
      },
      'prep_time_minutes': 10,
      'dietary_tags': ['Breakfast', 'High Protein'],
    },
    {
      'id': 'mock-9002',
      'title': 'Chicken Quinoa Plate',
      'summary': 'Lean chicken breast with quinoa and roasted vegetables.',
      'image_url': 'https://loremflickr.com/640/480/chicken?lock=9002',
      'ingredients': ['Chicken breast', 'Quinoa', 'Broccoli', 'Carrots'],
      'recipe_nutrition': {
        'calories': 560.0,
        'protein': 46.0,
        'carbs': 48.0,
        'fat': 18.0
      },
      'prep_time_minutes': 25,
      'dietary_tags': ['Lunch', 'Meal Prep'],
    },
    {
      'id': 'mock-9003',
      'title': 'Salmon Greens Dinner',
      'summary': 'Pan-seared salmon with garlic greens and sweet potato.',
      'image_url': 'https://loremflickr.com/640/480/salmon?lock=9003',
      'ingredients': ['Salmon', 'Spinach', 'Sweet potato', 'Garlic'],
      'recipe_nutrition': {
        'calories': 610.0,
        'protein': 42.0,
        'carbs': 38.0,
        'fat': 30.0
      },
      'prep_time_minutes': 30,
      'dietary_tags': ['Dinner', 'Omega-3'],
    },
  ];

  // Methods below are kept for API compat but now ignored
  Future<Map<String, dynamic>> generateRecipe({
    required List<String> ingredients,
    String? cuisine,
    String? dietaryRestrictions,
    int? maxCalories,
  }) async =>
      {};

}