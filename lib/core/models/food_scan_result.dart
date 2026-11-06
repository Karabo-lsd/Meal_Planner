class FoodScanResult {
  final String mealTitle;
  final String mealType;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double confidence;
  final Map<String, dynamic> raw;

  const FoodScanResult({
    required this.mealTitle,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidence,
    required this.raw,
  });

  FoodScanResult copyWith({
    String? mealTitle,
    String? mealType,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? confidence,
    Map<String, dynamic>? raw,
  }) {
    return FoodScanResult(
      mealTitle: mealTitle ?? this.mealTitle,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      confidence: confidence ?? this.confidence,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meal_title': mealTitle,
      'meal_type': mealType,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'confidence': confidence,
      'raw': raw,
    };
  }
}
