import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // ── Auth ──────────────────────────────────────────────────

  Future<AuthResponse> signIn(String email, String password) {
    return _supabase.auth
        .signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? fullName,
  }) {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  Future<void> signOut() => _supabase.auth.signOut();

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ── Google / Apple OAuth ──────────────────────────────────

  Future<void> signInWithGoogle() {
    return _supabase.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signInWithApple() {
    return _supabase.auth.signInWithOAuth(OAuthProvider.apple);
  }

  // ── Password reset ────────────────────────────────────────

  Future<void> sendPasswordReset(String email) {
    return _supabase.auth.resetPasswordForEmail(email);
  }
}