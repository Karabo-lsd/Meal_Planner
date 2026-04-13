import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── foods_master search ───────────────────────────────────

  Future<List<Map<String, dynamic>>> searchIngredients(String query,
      {int limit = 20}) async {
    return List<Map<String, dynamic>>.from(
      await _supabase
          .from('foods_master')
          .select('id, canonical_name, food_type, aliases, food_nutrition(*)')
          .ilike('canonical_name', '%$query%')
          .limit(limit),
    );
  }

  Future<Map<String, dynamic>> getIngredientById(dynamic id) async {
    return await _supabase
        .from('foods_master')
        .select('*, food_nutrition(*)')
        .eq('id', id.toString())
        .single();
  }

  Future<Map<String, dynamic>> getIngredientNutrition(
    String ingredientName, {
    double? amount,
    String? unit,
  }) async {
    final rows = await searchIngredients(ingredientName, limit: 1);
    if (rows.isEmpty) return {};
    final nutrition =
        rows.first['food_nutrition'] as Map<String, dynamic>? ?? {};
    return {
      'name': rows.first['canonical_name'],
      'calories': nutrition['per_100g_calories'],
      'protein': nutrition['per_100g_protein'],
      'carbs': nutrition['per_100g_carbs'],
      'fat': nutrition['per_100g_fat'],
    };
  }

  Future<List<Map<String, dynamic>>> getCommonIngredients(
      {String? category, int limit = 50}) async {
    var query = _supabase
        .from('foods_master')
        .select('id, canonical_name, food_type, food_nutrition(*)');
    if (category != null) {
      query = query.eq('food_category', category);
    }
    return List<Map<String, dynamic>>.from(await query.limit(limit));
  }

  Future<List<String>> getIngredientCategories() async {
    final rows = await _supabase
        .from('foods_master')
        .select('food_category')
        .not('food_category', 'is', null);
    return (rows as List)
        .map((r) => r['food_category'] as String)
        .toSet()
        .toList()
      ..sort();
  }

  // ── pantry_items CRUD ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPantryItems() async {
    return List<Map<String, dynamic>>.from(
      await _supabase
          .from('pantry_items')
          .select('*, foods_master(canonical_name, food_nutrition(*))')
          .eq('user_id', _userId)
          .order('created_at', ascending: false),
    );
  }

  // Backward-compat alias used by PantryNotifier
  Future<List<Map<String, dynamic>>> getCustomIngredients(
          {int skip = 0, int limit = 20}) =>
      getPantryItems();

  Future<Map<String, dynamic>> addPantryItem({
    String? canonicalFoodId,
    required String ingredientNameRaw,
    double quantity = 1.0,
    String unit = 'piece',
    DateTime? expiryDate,
    String source = 'manual',
  }) async {
    return await _supabase
        .from('pantry_items')
        .insert({
          'user_id': _userId,
          if (canonicalFoodId != null) 'canonical_food_id': canonicalFoodId,
          'ingredient_name_raw': ingredientNameRaw,
          'ingredient_name_normalized': ingredientNameRaw.toLowerCase().trim(),
          'quantity': quantity,
          'unit': unit,
          if (expiryDate != null)
            'expiry_date': expiryDate.toIso8601String().split('T')[0],
          'source': source,
        })
        .select()
        .single();
  }

  // Backward-compat alias used by old screens
  Future<Map<String, dynamic>> addCustomIngredient(
      Map<String, dynamic> data) =>
      addPantryItem(
        ingredientNameRaw: data['name'] as String? ??
            data['ingredient_name_raw'] as String? ??
            'Unknown',
        canonicalFoodId: data['canonical_food_id'] as String?,
        quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: data['unit'] as String? ?? 'piece',
      );

  Future<Map<String, dynamic>> updatePantryItem(
      String id, Map<String, dynamic> data) async {
    return await _supabase
        .from('pantry_items')
        .update(data)
        .eq('id', id)
        .select()
        .single();
  }

  Future<Map<String, dynamic>> updateCustomIngredient(
      dynamic id, Map<String, dynamic> data) =>
      updatePantryItem(id.toString(), data);

  Future<void> deletePantryItem(String id) async {
    await _supabase.from('pantry_items').delete().eq('id', id);
  }

  Future<void> deleteCustomIngredient(dynamic id) =>
      deletePantryItem(id.toString());

  // ── barcode lookup (Open Food Facts via Supabase cache) ───

  Future<Map<String, dynamic>> analyzeBarcode(String barcode) async {
    // Check if we have a cached scan for this barcode
    final cached = await _supabase
        .from('barcode_scans')
        .select('*, foods_master(*, food_nutrition(*))')
        .eq('barcode_value', barcode)
        .maybeSingle();

    if (cached != null) return cached;

    // No cache — caller should handle via FoodScanService / backend
    throw Exception('Barcode $barcode not found in local database.');
  }

  // Stubs kept for API compat (not backed by Supabase data)
  Future<List<Map<String, dynamic>>> getSeasonalIngredients(
          {String? season, String? location}) async =>
      [];

  Future<Map<String, dynamic>> convertUnits({
    required String ingredient,
    required double amount,
    required String fromUnit,
    required String toUnit,
  }) async =>
      {'amount': amount, 'unit': toUnit};

}