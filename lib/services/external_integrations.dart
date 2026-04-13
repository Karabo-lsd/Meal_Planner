import '../core/models/ingredient.dart';

abstract class ExternalIntegration {
  String get key;
}

abstract class CalorieTrackerIntegration implements ExternalIntegration {
  Future<void> syncCalories({
    required int consumedCalories,
    required DateTime date,
  });
}

abstract class GroceryListIntegration implements ExternalIntegration {
  Future<void> syncGroceryItems(List<Ingredient> ingredients);
}

class IntegrationRegistry {
  final Map<String, ExternalIntegration> _integrations = {};

  void register(ExternalIntegration integration) {
    _integrations[integration.key] = integration;
  }

  T? resolve<T extends ExternalIntegration>(String key) {
    final integration = _integrations[key];
    if (integration is T) {
      return integration;
    }
    return null;
  }

  Iterable<String> get keys => _integrations.keys;
}
