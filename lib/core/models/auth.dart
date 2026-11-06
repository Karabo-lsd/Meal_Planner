import 'user.dart';

/// Local app-level auth state used by auth screens.
/// Supabase auth events are streamed separately via [authStateProvider].
class AuthState {
  final bool isLoading;
  final User? user;
  final String? token;
  final String? error;

  /// Non-error status message (e.g. "Check your email to confirm your account").
  final String? successMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.token,
    this.error,
    this.successMessage,
  });

  bool belongsToUser(String userId) => user?.id == userId;

  AuthState copyWith({
    bool? isLoading,
    User? user,
    bool clearUser = false,
    String? token,
    String? error,
    String? successMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      token: token ?? this.token,
      error: error,
      successMessage: successMessage,
    );
  }
}
