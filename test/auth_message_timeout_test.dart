import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/providers.dart';

void main() {
  testWidgets('auth errors clear themselves after a few seconds', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authStateProvider.notifier);

    notifier.setError('Something went wrong. Please try again.');
    expect(container.read(authStateProvider).error, isNotNull);

    await tester.pump(const Duration(seconds: 6));
    expect(container.read(authStateProvider).error, isNull);
  });
}
