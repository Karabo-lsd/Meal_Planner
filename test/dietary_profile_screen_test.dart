import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/providers.dart';
import 'package:meal_planning_app/features/profile/dietary_profile_screen.dart';

class _TestDietaryProfileNotifier extends DietaryProfileNotifier {
  _TestDietaryProfileNotifier(super.ref, Map<String, dynamic> initialProfile) {
    state = initialProfile;
  }

  Map<String, dynamic>? savedProfile;

  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
    savedProfile = data;
    state = {...state, ...data};
  }
}

void main() {
  testWidgets('loads and saves allergies and foods to avoid', (tester) async {
    late _TestDietaryProfileNotifier profileNotifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerBootstrapEnabledProvider.overrideWithValue(false),
          dietaryProfileProvider.overrideWith(
            (ref) => profileNotifier = _TestDietaryProfileNotifier(ref, {
              'allergies': ['peanuts'],
              'excluded_ingredients': ['mushrooms'],
            }),
          ),
        ],
        child: const MaterialApp(home: DietaryProfileScreen()),
      ),
    );

    final textFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(textFields.elementAt(4).controller?.text, 'peanuts');
    expect(textFields.elementAt(5).controller?.text, 'mushrooms');

    await tester.enterText(find.byType(TextField).at(4), 'tree nuts, soy');
    await tester.enterText(find.byType(TextField).at(5), 'olives; celery');
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Save Profile'), findsOneWidget);
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    expect(profileNotifier.savedProfile?['allergies'], ['tree nuts', 'soy']);
    expect(profileNotifier.savedProfile?['excluded_ingredients'], [
      'olives',
      'celery',
    ]);
    expect(find.text('Dietary profile updated'), findsOneWidget);
  });
}
