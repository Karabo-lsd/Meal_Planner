import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/recipe.dart';
import 'package:meal_planning_app/features/tracking/meal_logging.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('meal logging sheet is readable in $brightness mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: _theme(brightness),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showLogMealSheet(
                    context,
                    ref,
                    Recipe(
                      id: '00000000-0000-0000-0000-000000000001',
                      title: 'Oatmeal',
                      calories: 320,
                    ),
                  ),
                  child: const Text('Open log sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open log sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Log "Oatmeal"'), findsOneWidget);
      expect(find.text('Servings'), findsOneWidget);
      expect(find.text('320 kcal total'), findsOneWidget);
      expect(find.text('I ate this'), findsOneWidget);
    });
  }
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: brightness,
  ),
  useMaterial3: true,
);
