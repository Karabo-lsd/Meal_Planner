class Ingredient {
  final String? id;               // pantry_items.id (UUID)
  final String name;              // ingredient_name_raw
  final String? canonicalFoodId; // canonical_food_id (UUID)
  final double? quantity;
  final String? unit;
  final DateTime? expiryDate;
  final int? calories;            // per 100g from food_nutrition
  final double? protein;
  final double? carbs;
  final double? fat;
  final bool custom;

  Ingredient({
    this.id,
    required this.name,
    this.canonicalFoodId,
    this.quantity,
    this.unit,
    this.expiryDate,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.custom = false,
  });

  /// Maps a pantry_items row (optionally joined with foods_master/food_nutrition).
  factory Ingredient.fromPantryJson(Map<String, dynamic> json) {
    final foodsMap = json['foods_master'] as Map<String, dynamic>?;
    final nutritionMap = foodsMap?['food_nutrition'] as Map<String, dynamic>?;
    final name = (json['ingredient_name_raw'] as String?) ??
        (foodsMap?['canonical_name'] as String?) ??
        'Unknown';
    return Ingredient(
      id: json['id'] as String?,
      name: name,
      canonicalFoodId: json['canonical_food_id'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'] as String)
          : null,
      calories: (nutritionMap?['per_100g_calories'] as num?)?.toInt(),
      protein: (nutritionMap?['per_100g_protein'] as num?)?.toDouble(),
      carbs: (nutritionMap?['per_100g_carbs'] as num?)?.toDouble(),
      fat: (nutritionMap?['per_100g_fat'] as num?)?.toDouble(),
      custom: true,
    );
  }

  /// Legacy JSON mapping — also handles pantry rows transparently.
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('ingredient_name_raw')) {
      return Ingredient.fromPantryJson(json);
    }
    return Ingredient(
      id: json['id']?.toString(),
      name: json['name'] as String,
      canonicalFoodId: json['canonical_food_id'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      calories: (json['calories'] as num?)?.toInt(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      custom: json['custom'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (canonicalFoodId != null) 'canonical_food_id': canonicalFoodId,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (expiryDate != null)
        'expiry_date': expiryDate!.toIso8601String().split('T')[0],
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      'custom': custom,
    };
  }
}
