import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/recipe.dart';
import 'package:meal_planning_app/core/providers.dart';

Recipe _recipe(String id) => Recipe(id: id, title: id);

void main() {
  test('refreshed recommendations replace stale feed recipes', () {
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue(null)],
    );
    final subscription = container.listen(recipeFeedProvider, (_, _) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    final notifier = container.read(recipeFeedProvider.notifier);
    notifier.seedInitial([_recipe('old-recipe')]);
    notifier.seedInitial([_recipe('new-spoonacular')]);

    expect(
      container.read(recipeFeedProvider).items.map((recipe) => recipe.id),
      ['new-spoonacular'],
    );
  });
}
