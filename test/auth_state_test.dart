import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/models/auth.dart';
import 'package:meal_planning_app/core/models/user.dart';

void main() {
  group('AuthState.belongsToUser', () {
    test('does not treat another account as the restored session', () {
      final state = AuthState(
        user: User(id: 'user-a', email: 'a@example.test'),
      );

      expect(state.belongsToUser('user-a'), isTrue);
      expect(state.belongsToUser('user-b'), isFalse);
    });

    test('does not match an empty auth state', () {
      expect(const AuthState().belongsToUser('user-a'), isFalse);
    });
  });

  test('profile row ID cannot override the authenticated user ID', () {
    final user = User.fromAuth(
      id: 'auth-user-id',
      email: 'user@example.test',
      profile: {
        'id': 'profile-row-id',
        'user_id': 'auth-user-id',
        'first_name': 'Test',
      },
    );

    expect(user.id, 'auth-user-id');
    expect(user.firstName, 'Test');
  });
}
