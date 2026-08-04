import 'package:dio/dio.dart';

import '../core/config/app_config.dart';

/// Client for the Spoonacular Recipe & Food API.
/// Calls [/recipes/complexSearch] with full nutrition and recipe info so
/// every result maps cleanly onto [Recipe.fromJson].
class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  /// Returns up to [number] recipes from Spoonacular, sorted by popularity.
  /// Pass [diet] and [includeIngredients] to personalise results.
  Future<List<Map<String, dynamic>>> searchRecipes({
    int number = 12,
    String? diet,
    List<String>? includeIngredients,
  }) async {
    if (!AppConfig.hasSpoonacularApiKey) {
      return const [];
    }

    final params = <String, dynamic>{
      'apiKey': AppConfig.spoonacularApiKey,
      'number': number,
      'addRecipeNutrition': true,
      'addRecipeInformation': true,
      'sort': 'popularity',
      'instructionsRequired': false,
    };

    final mappedDiet = diet != null ? _mapDiet(diet) : '';
    if (mappedDiet.isNotEmpty) params['diet'] = mappedDiet;

    if (includeIngredients != null && includeIngredients.isNotEmpty) {
      // Spoonacular accepts a comma-separated list; cap at 10 to stay within URL limits
      params['includeIngredients'] = includeIngredients.take(10).join(',');
    }

    final response = await _dio.get(
      '/recipes/complexSearch',
      queryParameters: params,
    );

    final results = (response.data['results'] as List<dynamic>?) ?? const [];
    return results
      .map((e) => _toRecipeMap(e as Map<String, dynamic>))
      .toList();
  }

  // ─── private helpers ──────────────────────────────────────────────────────

  /// Maps the app's [diet_type] values to the Spoonacular diet parameter.
  String _mapDiet(String diet) {
    switch (diet.toLowerCase().trim().replaceAll(RegExp(r'[\s\-]'), '_')) {
      case 'vegetarian':
        return 'vegetarian';
      case 'vegan':
        return 'vegan';
      case 'gluten_free':
        return 'gluten free';
      case 'ketogenic':
      case 'keto':
        return 'ketogenic';
      case 'paleo':
        return 'paleo';
      case 'pescetarian':
        return 'pescetarian';
      case 'whole30':
        return 'whole30';
      default:
        return '';
    }
  }

  /// Converts a Spoonacular recipe object into the map shape expected by
  /// [Recipe.fromJson].
  Map<String, dynamic> _toRecipeMap(Map<String, dynamic> s) {
    // ── nutrition ──────────────────────────────────────────
    final nutritionBlock = s['nutrition'] as Map<String, dynamic>?;
    final nutrients =
        (nutritionBlock?['nutrients'] as List<dynamic>?) ?? const [];

    double? extractNutrient(String name) {
      for (final n in nutrients) {
        final nm = n as Map<String, dynamic>;
        if ((nm['name'] as String? ?? '').toLowerCase() ==
            name.toLowerCase()) {
          return (nm['amount'] as num?)?.toDouble();
        }
      }
      return null;
    }

    // ── ingredients ────────────────────────────────────────
    final extIngredients =
        (s['extendedIngredients'] as List<dynamic>?) ?? const [];
    final ingredientNames = extIngredients
        .map((e) => (e as Map<String, dynamic>)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toSet() // deduplicate
        .toList();

    // ── tags / diets / cuisine ─────────────────────────────
    final diets = (s['diets'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final dishTypes = (s['dishTypes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final cuisines = (s['cuisines'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    // ── steps (analyzedInstructions) ───────────────────────
    final analyzedInstructions =
        (s['analyzedInstructions'] as List<dynamic>?) ?? const [];
    final steps = <String>[];
    for (final block in analyzedInstructions) {
      final blockSteps =
          ((block as Map<String, dynamic>)['steps'] as List<dynamic>?) ??
              const [];
      for (final step in blockSteps) {
        final text =
            (step as Map<String, dynamic>)['step'] as String? ?? '';
        if (text.isNotEmpty) steps.add(text);
      }
    }

    // ── summary (strip HTML tags) ──────────────────────────
    final rawSummary = s['summary'] as String? ?? '';
    final summary =
        rawSummary.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return {
      // Prefix id with 'sp-' so it never collides with Supabase UUIDs
      'id': 'sp-${s['id']}',
      'title': s['title'] as String? ?? '',
      'summary': summary.isNotEmpty ? summary : null,
      'image_url': s['image'] as String?,
      'calories': extractNutrient('Calories')?.round(),
      'protein': extractNutrient('Protein'),
      'carbs': extractNutrient('Carbohydrates'),
      'fat': extractNutrient('Fat'),
      'prep_time_minutes': s['readyInMinutes'] as int?,
      'ingredients': ingredientNames,
      'steps': steps.isNotEmpty ? steps : null,
      'dietary_tags': dishTypes,
      'health_labels': diets,
      'cuisine': cuisines.isNotEmpty ? cuisines.first : null,
    };
  }
}
