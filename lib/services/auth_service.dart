import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  static const emailConfirmationRedirect = 'mealplanner://auth-callback';
  static const passwordResetRedirect = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'https://karabo-lsd.github.io/Meal_Planner/',
  );

  // ── Auth ──────────────────────────────────────────────────

  Future<AuthResponse> signIn(String email, String password) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? fullName,
  }) {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailConfirmationRedirect,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  Future<void> signOut() => _supabase.auth.signOut();

  Future<void> signOutLocally() =>
      _supabase.auth.signOut(scope: SignOutScope.local);

  Future<void> deleteAccount() async {
    await ApiClient.instance.delete<void>('/api/account');
  }

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ── Google / Apple OAuth ──────────────────────────────────

  Future<bool> signInWithGoogle() {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: emailConfirmationRedirect,
    );
  }

  Future<bool> signInWithApple() {
    return _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: emailConfirmationRedirect,
    );
  }

  // ── Password reset ────────────────────────────────────────

  Future<void> sendPasswordReset(String email) {
    return _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? passwordResetRedirect : emailConfirmationRedirect,
    );
  }

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> updateEmail(String email) async {
    await _supabase.auth.updateUser(UserAttributes(email: email));
  }
}
