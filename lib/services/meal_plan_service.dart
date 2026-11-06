import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/ingredient.dart';
import '../core/models/recipe.dart';

class MealPlanService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  List<Map<String, dynamic>> _withoutTheMealDB(
    List<Map<String, dynamic>> items,
  ) => items.where((item) {
    final recipe = item['recipes'];
    if (recipe is! Map) return true;
    final provider = (recipe['source_provider']?.toString() ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return provider != 'themealdb' && provider != 'mealdb';
  }).toList();

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T')[0];

  bool _isUuid(String value) {
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidRe.hasMatch(value);
  }

  Future<Map<String, dynamic>?> getActivePlan({DateTime? forDate}) async {
    final date = _dateOnly(forDate ?? DateTime.now());
    final row = await _supabase
        .from('meal_plans')
        .select()
        .eq('user_id', _userId)
        .lte('start_date', date)
        .gte('end_date', date)
        .order('created_at', ascending: false)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> getPlanItems(String planId) async {
    try {
      final rows = await _supabase
          .from('meal_plan_items')
          .select(
            '*, recipes(id,title,source_provider,image_url,prep_time_minutes,recipe_nutrition(calories,protein,carbs,fat),recipe_ingredients(ingredient_name_raw)), foods_master(canonical_name)',
          )
          .eq('meal_plan_id', planId)
          .order('plan_date')
          .order('meal_slot');
      return _withoutTheMealDB(List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      final rows = await _supabase
          .from('meal_plan_items')
          .select(
            '*, recipes(id,title,source_provider,image_url,prep_time_minutes,recipe_nutrition(calories,protein,carbs,fat),recipe_ingredients(ingredient_name_raw)), foods_master(canonical_name)',
          )
          .eq('plan_id', planId)
          .order('date')
          .order('meal_type');
      return _withoutTheMealDB(List<Map<String, dynamic>>.from(rows));
    }
  }

  Future<Map<String, dynamic>> createWeeklyPlan({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
  }) async {
    final weekStart = _startOfWeek(DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 6));

    final recipeCandidates = <String>{
      ...recipes.map((r) => r.id).where(_isUuid),
      ...await _loadCanonicalRecipeIds(),
    }.toList();
    final pantryCandidates = <String>{
      ...pantry
          .map((p) => p.canonicalFoodId)
          .whereType<String>()
          .where(_isUuid),
      ...await _loadCanonicalPantryFoodIds(),
    }.toList();

    if (recipeCandidates.isEmpty && pantryCandidates.isEmpty) {
      throw StateError(
        'Unable to generate a plan yet. Add items to pantry or refresh recommendations so canonical foods/recipes can be linked.',
      );
    }

    final plan = await _supabase
        .from('meal_plans')
        .insert({
          'user_id': _userId,
          'start_date': _dateOnly(weekStart),
          'end_date': _dateOnly(weekEnd),
        })
        .select()
        .single();

    final planId = plan['id'].toString();

    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));

      final recipeId = recipeCandidates.isNotEmpty
          ? recipeCandidates[i % recipeCandidates.length]
          : null;
      final canonicalFoodId = pantryCandidates.isNotEmpty
          ? pantryCandidates[i % pantryCandidates.length]
          : null;

      await _insertPlanItem(
        planId: planId,
        date: _dateOnly(day),
        recipeId: recipeId,
        canonicalFoodId: canonicalFoodId,
      );
    }

    return Map<String, dynamic>.from(plan);
  }

  Future<List<String>> _loadCanonicalRecipeIds() async {
    try {
      final rows = await _supabase
          .from('recipes')
          .select('id')
          .or('source_provider.is.null,source_provider.not.ilike.*themealdb*')
          .limit(21);
      return (rows as List)
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where(_isUuid)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<String>> _loadCanonicalPantryFoodIds() async {
    try {
      final rows = await _supabase
          .from('pantry_items')
          .select('canonical_food_id')
          .eq('user_id', _userId)
          .not('canonical_food_id', 'is', null)
          .limit(21);
      return (rows as List)
          .map((row) => row['canonical_food_id']?.toString())
          .whereType<String>()
          .where(_isUuid)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _insertPlanItem({
    required String planId,
    required String date,
    String? recipeId,
    String? canonicalFoodId,
  }) async {
    final effectiveRecipeId = recipeId != null && _isUuid(recipeId)
        ? recipeId
        : null;
    final effectiveFoodId = canonicalFoodId != null && _isUuid(canonicalFoodId)
        ? canonicalFoodId
        : null;

    if (effectiveRecipeId == null && effectiveFoodId == null) {
      return;
    }

    try {
      await _supabase.from('meal_plan_items').insert({
        'meal_plan_id': planId,
        'plan_date': date,
        'meal_slot': 'dinner',
        ...?effectiveRecipeId != null ? {'recipe_id': effectiveRecipeId} : null,
        ...?effectiveFoodId != null
            ? {'canonical_food_id': effectiveFoodId}
            : null,
        'portion_multiplier': 1,
      });
      return;
    } catch (_) {
      await _supabase.from('meal_plan_items').insert({
        'plan_id': planId,
        'date': date,
        'meal_type': 'dinner',
        ...?effectiveRecipeId != null ? {'recipe_id': effectiveRecipeId} : null,
        ...?effectiveFoodId != null ? {'food_id': effectiveFoodId} : null,
        'quantity': 1,
      });
    }
  }
}
