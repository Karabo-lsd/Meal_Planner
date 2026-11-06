import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/profile_onboarding.dart';
import 'package:meal_planning_app/core/providers.dart';

void main() {
  group('hasCompleteOnboardingProfile', () {
    test('returns false for a profile missing core details', () {
      final profile = {
        'first_name': 'Ada',
        'age': 29,
      };

      expect(hasCompleteOnboardingProfile(profile), isFalse);
    });

    test('returns true when the required onboarding data is present', () {
      final profile = {
        'first_name': 'Ada',
        'age': 29,
        'height': 165.0,
        'weight': 58.0,
        'goal': 'lose_weight',
        'daily_calorie_target': 1800,
        'diet_type': 'balanced',
      };

      expect(hasCompleteOnboardingProfile(profile), isTrue);
    });

    test('flags incomplete profiles for the delayed profile prompt', () {
      final profile = {
        'first_name': 'Ada',
        'age': 29,
      };

      expect(shouldPromptForProfileSetup(profile), isTrue);
    });
  });

  group('formatAuthErrorMessage', () {
    test('converts connection refused errors into a friendly offline message', () {
      final message = formatAuthErrorMessage(Exception('ClientException with SocketException: Connection refused'));

      expect(message, contains('not available right now'));
      expect(message, isNot(contains('127.0.0.1')));
    });
  });
}
