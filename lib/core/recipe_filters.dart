import 'models/recipe.dart';

class RecipeFilters {
  static List<Recipe> apply(
    List<Recipe> recipes, {
    String quickFilter = 'All',
    String category = 'All',
  }) {
    return recipes
        .where(
          (recipe) =>
              matchesQuickFilter(recipe, quickFilter) &&
              matchesCategory(recipe, category),
        )
        .toList();
  }

  static bool matchesQuickFilter(Recipe recipe, String filter) {
    if (filter == 'All') return true;

    final metadata = _metadata(recipe);
    final labels = _labels(recipe);
    switch (filter) {
      case 'Breakfast':
        return _hasLabel(labels, const ['breakfast']) ||
            _hasAny(metadata, const [
              'breakfast',
              'pancake',
              'pancakes',
              'waffle',
              'waffles',
              'oatmeal',
              'porridge',
              'french toast',
              'omelet',
              'omelette',
              'eggs benedict',
              'granola',
              'breakfast burrito',
              'breakfast sandwich',
              'hash browns',
            ]);
      case 'Lunch':
        return _hasLabel(labels, const ['lunch']) ||
            _hasAny(metadata, const [
              'lunch',
              'sandwich',
              'salad',
              'soup',
              'wrap',
              'lunch bowl',
              'panini',
              'quesadilla',
              'pita',
            ]);
      case 'Dinner':
        return _hasLabel(labels, const ['dinner', 'main course']) ||
            _hasAny(metadata, const [
              'dinner',
              'main course',
              'roast',
              'casserole',
              'curry',
              'stir fry',
              'stew',
              'braised',
            ]);
      case 'High Protein':
        return _isHighProtein(recipe) ||
            _hasLabel(labels, const ['high protein', 'protein-rich','protein']);
      case 'Vegan':
        return _hasLabel(labels, const ['vegan', 'plant based', 'plant-based']);
      case 'Keto':
        return _hasLabel(labels, const ['keto', 'ketogenic']) ||
            _hasLabel(labels, const ['low carb', 'low-carb']) ||
            _isLowCarb(recipe);
      case 'Quick Meals':
        return (recipe.prepTime != null && recipe.prepTime! <= 25) ||
            _hasLabel(labels, const ['quick', 'quick meal', 'easy']);
      case 'Healthy':
        return _isHealthy(metadata, labels);
      case 'Low Carb':
        return _hasLabel(labels, const ['low carb', 'low-carb', 'keto']) ||
            _isLowCarb(recipe);
      default:
        return true;
    }
  }

  static bool matchesCategory(Recipe recipe, String category) {
    if (category == 'All') return true;

    final metadata = _metadata(recipe);
    final labels = _labels(recipe);
    switch (category) {
      case 'Healthy':
        return _isHealthy(metadata, labels);
      case 'Protein':
        return _isHighProtein(recipe) ||
            _hasLabel(labels, const ['high protein', 'protein-rich']);
      case 'Comfort Food':
        return _hasAny(metadata, const [
          'comfort food',
          'pizza',
          'burger',
          'mac and cheese',
          'mac cheese',
          'macaroni and cheese',
          'lasagna',
          'fried chicken',
          'meatloaf',
          'fried rice',
          'pot pie',
          'shepherds pie',
          'shepherd s pie',
          'meat pie',
        ]);
      case 'Drinks':
        return _hasLabel(labels, const ['drink', 'beverage']) ||
            _hasAny(metadata, const [
              'drink',
              'beverage',
              'smoothie',
              'juice',
              'lemonade',
              'milkshake',
              'tea',
              'coffee',
            ]);
      case 'Pasta':
        return _hasAny(metadata, const [
          'pasta',
          'spaghetti',
          'linguine',
          'fettuccine',
          'penne',
          'macaroni',
          'ravioli',
          'tortellini',
          'rigatoni',
          'fusilli',
        ]);
      case 'Breakfast':
        return matchesQuickFilter(recipe, 'Breakfast');
      case 'Desserts':
        return _hasLabel(labels, const ['dessert', 'desserts']) ||
            _hasAny(metadata, const [
              'dessert',
              'cake',
              'cookie',
              'cookies',
              'brownie',
              'pudding',
              'ice cream',
              'pie',
              'tart',
            ]);
      default:
        return true;
    }
  }

  static bool _isHighProtein(Recipe recipe) => (recipe.protein ?? 0) >= 25;

  static bool _isLowCarb(Recipe recipe) => (recipe.carbs ?? 1000) <= 20;

  static bool _isHealthy(String metadata, Set<String> labels) {
    const healthLabels = [
      'healthy',
      'balanced',
      'whole food',
      'low sodium',
      'low fat',
      'high fiber',
      'heart healthy',
    ];
    return _hasLabel(labels, healthLabels) || _hasAny(metadata, healthLabels);
  }

  static Set<String> _labels(Recipe recipe) {
    final labels = <String>{
      ...?recipe.tags,
      ...?recipe.supportedDiets,
      if (recipe.mealType != null) recipe.mealType!,
    };
    return labels.map(_normalize).toSet();
  }

  static String _metadata(Recipe recipe) => _normalize(
    [
      recipe.title,
      recipe.description ?? '',
      recipe.cuisine ?? '',
      recipe.mealType ?? '',
      ...?recipe.tags,
      ...?recipe.supportedDiets,
      ...?recipe.ingredients,
    ].join(' '),
  );

  static bool _hasAny(String text, List<String> values) {
    final padded = ' $text ';
    return values.any((value) {
      final normalized = _normalize(value);
      return padded.contains(' $normalized ');
    });
  }

  static bool _hasLabel(Set<String> labels, List<String> values) =>
      values.map(_normalize).any(labels.contains);

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
