import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/features/auth/screens/reset_password_screen.dart';

void main() {
  testWidgets('requires a new password of at least eight characters', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordScreen()));

    await tester.tap(find.text('Save new password'));
    await tester.pump();

    expect(
      find.text('Use a password with at least 8 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('requires matching new passwords', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordScreen()));

    await tester.enterText(
      find.widgetWithText(TextField, 'New password'),
      'long-password',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm new password'),
      'different-password',
    );
    await tester.tap(find.text('Save new password'));
    await tester.pump();

    expect(find.text('The passwords do not match.'), findsOneWidget);
  });
}
