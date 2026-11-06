import 'package:supabase_flutter/supabase_flutter.dart';

import 'recommendation_service.dart';

const _allowedRecipeSourceFilter =
    'source_provider.is.null,source_provider.not.ilike.*themealdb*';

bool _isTheMealDBRecipe(Map recipe) {
  final provider = (recipe['source_provider']?.toString() ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  return provider == 'themealdb' || provider == 'mealdb';
}

class RecipeService {
  final _recommendations = RecommendationService();
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

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
          .select('*, recipe_nutrition(*)')
          .or(_allowedRecipeSourceFilter);

      if (search != null && search.isNotEmpty) {
        query = query.ilike('title', '%$search%');
      }
      if (maxPrepTime != null) {
        query = query.lte('prep_time_minutes', maxPrepTime);
      }

      final result = await query.order('title').range(skip, skip + limit - 1);
      return List<Map<String, dynamic>>.from(result);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> getRecipeById(dynamic recipeId) async {
    return await _supabase
        .from('recipes')
        .select(
          '*, recipe_nutrition(*), recipe_ingredients(*, foods_master(canonical_name))',
        )
        .eq('id', recipeId.toString())
        .or(_allowedRecipeSourceFilter)
        .single();
  }

  Future<List<Map<String, dynamic>>> getRecommendedRecipes({
    int limit = 100,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return const [];
    final items = await _recommendations.recommend(
      userId: userId,
      requestType: 'search',
      limit: limit,
    );
    return _recipeMaps(items);
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
            ingredients.map((e) => e.toLowerCase().trim()).toList(),
          );

      final recipeIds = (rows as List)
          .map((r) => r['recipe_id'] as String)
          .toSet()
          .take(limit)
          .toList();

      if (recipeIds.isEmpty) return [];

      final recipes = await _supabase
          .from('recipes')
          .select('*, recipe_nutrition(*)')
          .inFilter('id', recipeIds)
          .or(_allowedRecipeSourceFilter);

      return List<Map<String, dynamic>>.from(recipes);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    required List<String> ingredients,
    required Map<String, dynamic> goals,
    String? dietaryPreference,
    int limit = 100,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return const [];
    final items = await _recommendations.recommend(
      userId: userId,
      requestType: 'search',
      limit: limit,
      context: {
        'pantry_ingredients': ingredients,
        'dietary_preference': ?dietaryPreference,
        ...goals,
      },
    );
    return _recipeMaps(items);
  }

  List<Map<String, dynamic>> _recipeMaps(
    List<Map<String, dynamic>> recommendations,
  ) => recommendations
      .map((item) => item['recipe'])
      .whereType<Map>()
      .map((recipe) => Map<String, dynamic>.from(recipe))
      .toList();

  // ── Saved recipes ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSavedRecipes({
    int skip = 0,
    int limit = 20,
  }) async {
    final rows = await _supabase
        .from('saved_recipes')
        .select(
          '*, recipes(*, recipe_nutrition(*), recipe_ingredients(*, foods_master(canonical_name)))',
        )
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .range(skip, skip + limit - 1);
    return List<Map<String, dynamic>>.from(rows).where((row) {
      final recipe = row['recipes'];
      return recipe is! Map || !_isTheMealDBRecipe(recipe);
    }).toList();
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
    Map<String, dynamic> recipeData,
  ) async {
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

  // Methods below are kept for API compat but now ignored
  Future<Map<String, dynamic>> generateRecipe({
    required List<String> ingredients,
    String? cuisine,
    String? dietaryRestrictions,
    int? maxCalories,
  }) async => {};
}
