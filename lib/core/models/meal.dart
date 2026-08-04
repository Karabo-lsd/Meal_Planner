/// Maps to the `food_logs` table in Supabase.
class Meal {
  final String id;
  final String userId;
  final String logDate;   // 'YYYY-MM-DD'
  final String mealSlot;  // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String? canonicalFoodId;
  final String? recipeId;
  final String source;    // 'manual' | 'recipe' | 'image_scan' | 'imported'
  final double? quantity;
  final String? unit;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final bool estimationFlag;
  final DateTime createdAt;

  // Backward-compat accessors used by existing screens
  String get mealType => mealSlot;
  String? get imageUrl => null;
  Map<String, dynamic>? get analysisResult => null;

  Meal({
    required this.id,
    required this.userId,
    required this.logDate,
    required this.mealSlot,
    this.canonicalFoodId,
    this.recipeId,
    this.source = 'manual',
    this.quantity,
    this.unit,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.estimationFlag = false,
    required this.createdAt,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'].toString(),
      userId: json['user_id'] as String? ?? '',
      logDate: json['log_date'] as String? ??
          (json['logged_at'] as String?)?.split('T')[0] ??
          DateTime.now().toIso8601String().split('T')[0],
      mealSlot:
          json['meal_slot'] as String? ?? json['meal_type'] as String? ?? 'snack',
      canonicalFoodId: json['canonical_food_id'] as String?,
      recipeId: json['recipe_id'] as String?,
      source: json['source'] as String? ?? 'manual',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      calories: ((json['calories'] ?? json['total_calories']) as num?)?.toDouble(),
      protein: ((json['protein'] ?? json['total_protein']) as num?)?.toDouble(),
      carbs: ((json['carbs'] ?? json['total_carbs']) as num?)?.toDouble(),
      fat: ((json['fat'] ?? json['total_fat']) as num?)?.toDouble(),
      estimationFlag: json['estimation_flag'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'log_date': logDate,
      'meal_slot': mealSlot,
      if (canonicalFoodId != null) 'canonical_food_id': canonicalFoodId,
      if (recipeId != null) 'recipe_id': recipeId,
      'source': source,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      'estimation_flag': estimationFlag,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
