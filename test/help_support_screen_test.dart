import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/features/profile/help_support_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('help screen is readable in $brightness mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: _theme(brightness), home: const HelpSupportScreen()),
      );

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Frequently asked questions'), findsOneWidget);
      expect(find.text('How do I save a recipe?'), findsOneWidget);
      expect(
        find.text('Lunch icons created by Magnific - Flaticon'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not configured in this version'),
        findsOneWidget,
      );

      await tester.tap(find.text('How do I save a recipe?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Open a recipe'), findsOneWidget);
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
