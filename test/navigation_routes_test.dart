import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/features/profile/help_support_screen.dart';
import 'package:meal_planning_app/features/profile/manage_account_screen.dart';
import 'package:meal_planning_app/features/recipes/nutrition_screen.dart';
import 'package:meal_planning_app/main.dart';

void main() {
  testWidgets('profile destinations resolve to their correct screens', (
    tester,
  ) async {
    final routes = appRoutes();
    late Widget savedRecipesPage;
    late Widget manageAccountPage;
    late Widget helpSupportPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            savedRecipesPage = routes['/savedRecipes']!(context);
            manageAccountPage = routes['/manageAccount']!(context);
            helpSupportPage = routes['/helpSupport']!(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(savedRecipesPage, isA<NutritionScreen>());
    expect(manageAccountPage, isA<ManageAccountScreen>());
    expect(helpSupportPage, isA<HelpSupportScreen>());
  });
}
