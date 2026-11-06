import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/shared/widgets/privacy_notice.dart';

void main() {
  testWidgets('POPIA notice can be expanded and collapsed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyNotice())),
    );

    expect(find.text('Privacy & POPIA'), findsOneWidget);
    expect(
      find.textContaining('Protection of Personal Information Act'),
      findsNothing,
    );

    await tester.tap(find.text('Privacy & POPIA'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Protection of Personal Information Act'),
      findsOneWidget,
    );

    await tester.tap(find.text('Privacy & POPIA'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Protection of Personal Information Act'),
      findsNothing,
    );
  });
}
