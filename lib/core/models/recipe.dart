class Recipe {
  final String id;
  final String title;
  final String? description;
  final List<String>? ingredients;
  final List<String>? steps;
  final List<List<String>>? stepIngredients;
  final String? imageUrl;
  final int? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String? difficulty;
  final int? prepTime;
  final List<String>? tags;
  final List<String>? supportedDiets;
  final String? cuisine;
  final String? mealType;
  final int? totalTimeMinutes;
  final String? sourceProvider;

  Recipe({
    required this.id,
    required this.title,
    this.description,
    this.ingredients,
    this.steps,
    this.stepIngredients,
    this.imageUrl,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.difficulty,
    this.prepTime,
    this.tags,
    this.supportedDiets,
    this.cuisine,
    this.mealType,
    this.totalTimeMinutes,
    this.sourceProvider,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawNutrition = json['recipe_nutrition'];
    final nutritionMap = rawNutrition is Map<String, dynamic>
        ? rawNutrition
        : rawNutrition is List &&
              rawNutrition.isNotEmpty &&
              rawNutrition.first is Map
        ? Map<String, dynamic>.from(rawNutrition.first as Map)
        : null;

    // Supabase join: recipe_ingredients is a list with optional foods_master
    final joinedIngredients = (json['recipe_ingredients'] as List<dynamic>?)
        ?.map((e) {
          final ri = e as Map<String, dynamic>;
          return (ri['ingredient_name_raw'] as String?) ??
              ((ri['foods_master'] as Map<String, dynamic>?)?['canonical_name']
                  as String?) ??
              '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
    final rawIngredients = (json['ingredients'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final ingredients =
        joinedIngredients != null && joinedIngredients.isNotEmpty
        ? joinedIngredients
        : rawIngredients;

    return Recipe(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['summary'] as String? ?? json['description'] as String?,
      ingredients: ingredients,
      steps: (json['steps'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      stepIngredients: (json['step_ingredients'] as List<dynamic>?)
          ?.map(
            (step) =>
                (step as List<dynamic>).map((item) => item.toString()).toList(),
          )
          .toList(),
      imageUrl: json['image_url'] as String?,
      calories: nutritionMap != null
          ? (nutritionMap['calories'] as num?)?.round()
          : (json['calories'] as num?)?.round(),
      protein: nutritionMap != null
          ? (nutritionMap['protein'] as num?)?.toDouble()
          : (json['protein'] as num?)?.toDouble(),
      carbs: nutritionMap != null
          ? (nutritionMap['carbs'] as num?)?.toDouble()
          : (json['carbs'] as num?)?.toDouble(),
      fat: nutritionMap != null
          ? (nutritionMap['fat'] as num?)?.toDouble()
          : (json['fat'] as num?)?.toDouble(),
      difficulty: json['difficulty'] as String?,
      prepTime:
          (json['prep_time_minutes'] as int?) ?? (json['prep_time'] as int?),
      tags:
          (json['dietary_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      supportedDiets:
          (json['health_labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['supported_diets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      cuisine: json['cuisine'] as String?,
      mealType: json['meal_type'] as String?,
      totalTimeMinutes: json['total_time_minutes'] as int?,
      sourceProvider: json['source_provider'] as String?,
    );
  }

  /// Returns a copy of this recipe with [imageUrl] overridden.
  /// Used when the UI resolves a fallback URL that isn't stored on the model.
  Recipe copyWithImageUrl(String url) => Recipe(
    id: id,
    title: title,
    description: description,
    ingredients: ingredients,
    steps: steps,
    stepIngredients: stepIngredients,
    imageUrl: url,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    difficulty: difficulty,
    prepTime: prepTime,
    tags: tags,
    supportedDiets: supportedDiets,
    cuisine: cuisine,
    mealType: mealType,
    totalTimeMinutes: totalTimeMinutes,
    sourceProvider: sourceProvider,
  );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (ingredients != null) 'ingredients': ingredients,
      if (steps != null) 'steps': steps,
      if (stepIngredients != null) 'step_ingredients': stepIngredients,
      if (imageUrl != null) 'image_url': imageUrl,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (difficulty != null) 'difficulty': difficulty,
      if (prepTime != null) 'prep_time': prepTime,
      if (tags != null) 'tags': tags,
      if (supportedDiets != null) 'supported_diets': supportedDiets,
      if (cuisine != null) 'cuisine': cuisine,
      if (mealType != null) 'meal_type': mealType,
      if (sourceProvider != null) 'source_provider': sourceProvider,
    };
  }
}
