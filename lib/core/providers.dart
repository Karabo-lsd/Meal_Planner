import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

// services
import '../services/services.dart';
// models
import 'models/auth.dart';
import 'models/user.dart';
import 'models/ingredient.dart';
import 'models/recipe.dart';
import 'profile_onboarding.dart';

/// Providers for various application services. These wrap the singletons
/// defined in `services.dart` and expose them to the widget layer via
/// Riverpod.

final apiClientProvider = Provider.autoDispose((ref) => ApiClient.instance);
final authServiceProvider = Provider.autoDispose((ref) => AuthService());
final mealServiceProvider = Provider.autoDispose((ref) => MealService());
final mealPlanServiceProvider = Provider.autoDispose((ref) => MealPlanService());
final recipeServiceProvider = Provider.autoDispose((ref) => RecipeService());
final analyticsServiceProvider = Provider.autoDispose((ref) => AnalyticsService());
final userProfileServiceProvider = Provider.autoDispose((ref) => UserProfileService());
final ingredientServiceProvider = Provider.autoDispose((ref) => IngredientService());
final voiceServiceProvider = Provider.autoDispose((ref) => VoiceService());
final foodScanServiceProvider = Provider.autoDispose(
  (ref) => FoodScanService(
    mealService: ref.read(mealServiceProvider),
    ingredientService: ref.read(ingredientServiceProvider),
  ),
);
final providerBootstrapEnabledProvider = Provider<bool>((ref) => true);
final integrationRegistryProvider = Provider((ref) => IntegrationRegistry());

// ── Supabase ─────────────────────────────────────────────────────────────────
final supabaseProvider = Provider<supa.SupabaseClient>(
    (_) => supa.Supabase.instance.client);

/// Streams every Supabase auth event (sign-in, sign-out, token refresh).
/// Watch this in main.dart for auth-based routing.
final supabaseAuthStreamProvider = StreamProvider<supa.AuthState>((ref) =>
    supa.Supabase.instance.client.auth.onAuthStateChange);

/// The currently authenticated Supabase user, or null when signed out.
final currentSupabaseUserProvider = Provider<supa.User?>((ref) {
  ref.watch(supabaseAuthStreamProvider);
  return supa.Supabase.instance.client.auth.currentUser;
});

// pantry state: list of user's ingredients
class PantryNotifier extends StateNotifier<List<Ingredient>> {
  PantryNotifier(this.ref) : super(const []) {
    if (ref.read(providerBootstrapEnabledProvider)) {
      _loadPantry();
    }
  }

  final Ref ref;

  String? get _uid => supa.Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadPantry() async {
    final userId = _uid;
    if (userId == null) return;

    // 1. Serve cached data immediately so the UI is never blank.
    final cached = SessionStorage.loadPantry(userId);
    if (cached != null) {
      state = cached.map((e) => Ingredient.fromPantryJson(e)).toList();
    }

    // 2. Fetch fresh from Supabase in the background.
    try {
      final items = await ref.read(ingredientServiceProvider).getPantryItems();
      state = items.map((e) => Ingredient.fromPantryJson(e)).toList();
      SessionStorage.savePantry(userId, items);
    } catch (_) {
      // Keep cached data if network is unavailable.
    }
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    if (ingredient.id == null) {
      final data = await ref
          .read(ingredientServiceProvider)
          .addCustomIngredient(ingredient.toJson());
      ingredient = Ingredient.fromPantryJson(data);
    }
    state = [...state, ingredient];
    _persistPantry();
  }

  Future<void> removeIngredient(Ingredient ingredient) async {
    if (ingredient.id != null) {
      await ref
          .read(ingredientServiceProvider)
          .deleteCustomIngredient(ingredient.id!);
    }
    state = state.where((i) => i.id != ingredient.id || i.name != ingredient.name).toList();
    _persistPantry();
  }

  void _persistPantry() {
    final userId = _uid;
    if (userId == null) return;
    final raw = state.map((i) => i.toJson()..['ingredient_name_raw'] ??= i.name).toList();
    SessionStorage.savePantry(userId, raw.cast<Map<String, dynamic>>());
  }
}

final pantryProvider = StateNotifierProvider<PantryNotifier, List<Ingredient>>(
  (ref) => PantryNotifier(ref),
);

// dietary profile stored separately
final dietaryProfileProvider = StateNotifierProvider<DietaryProfileNotifier, Map<String, dynamic>>(
  (ref) => DietaryProfileNotifier(ref),
);

class DietaryProfileNotifier extends StateNotifier<Map<String, dynamic>> {
  DietaryProfileNotifier(this.ref) : super({}) {
    if (ref.read(providerBootstrapEnabledProvider)) {
      _loadProfile();
    }
  }

  final Ref ref;

  String? get _uid => supa.Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadProfile() async {
    final userId = _uid;
    if (userId == null) return;

    // 1. Show cached profile instantly.
    final cached = SessionStorage.loadProfile(userId);
    if (cached != null && cached.isNotEmpty) state = cached;

    // 2. Refresh from Supabase in background.
    try {
      final service = ref.read(userProfileServiceProvider);
      final profile = await service.getProfile() ?? const <String, dynamic>{};
      final prefs =
          await service.getDietaryPreferences() ?? const <String, dynamic>{};
      final fresh = {
        ...profile,
        if (prefs['diet_type'] != null) 'diet_type': prefs['diet_type'],
        'preferences': {
          ...(profile['preferences'] is Map
              ? Map<String, dynamic>.from(profile['preferences'] as Map)
              : const <String, dynamic>{}),
          if (prefs['diet_type'] != null) 'diet': prefs['diet_type'],
        },
      };

      if (fresh.isNotEmpty) {
        state = fresh;
        SessionStorage.saveProfile(userId, fresh);
      }
    } catch (_) {}
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final mergedProfile = <String, dynamic>{...state};

    if (data['preferences'] is Map && mergedProfile['preferences'] is Map) {
      mergedProfile['preferences'] = {
        ...Map<String, dynamic>.from(mergedProfile['preferences'] as Map),
        ...Map<String, dynamic>.from(data['preferences'] as Map),
      };
    } else if (data['preferences'] is Map) {
      mergedProfile['preferences'] = Map<String, dynamic>.from(data['preferences'] as Map);
    }

    if (data['goals'] is Map && mergedProfile['goals'] is Map) {
      mergedProfile['goals'] = {
        ...Map<String, dynamic>.from(mergedProfile['goals'] as Map),
        ...Map<String, dynamic>.from(data['goals'] as Map),
      };
    } else if (data['goals'] is Map) {
      mergedProfile['goals'] = Map<String, dynamic>.from(data['goals'] as Map);
    }

    for (final entry in data.entries) {
      if (entry.key != 'preferences' && entry.key != 'goals') {
        mergedProfile[entry.key] = entry.value;
      }
    }

    state = mergedProfile;

    final userId = _uid;
    if (userId != null) {
      await SessionStorage.saveProfile(userId, state);
    }

    try {
      final serverProfile = await ref.read(userProfileServiceProvider).updateProfile(data);
      if (serverProfile.isNotEmpty) {
        state = {
          ...mergedProfile,
          ...serverProfile,
        };
        if (userId != null) {
          await SessionStorage.saveProfile(userId, state);
        }
      }
    } catch (_) {
      // Keep the locally updated profile so the app feels responsive even when
      // the backend is unavailable.
      rethrow;
    }
  }

  bool hasCompletedOnboarding() => hasCompleteOnboardingProfile(state);
}

List<Recipe> _fallbackRecipes() {
  return [
    Recipe(
      id: '9901',
      title: 'Power Breakfast Bowl',
      description: 'Greek yogurt, oats, berries, and chia seeds.',
      ingredients: const ['Greek yogurt', 'Oats', 'Berries', 'Chia seeds'],
      calories: 420,
      protein: 28,
      carbs: 44,
      fat: 12,
      difficulty: 'easy',
      prepTime: 10,
      tags: const ['Breakfast', 'High Protein'],
      supportedDiets: const ['balanced', 'high_protein'],
    ),
    Recipe(
      id: '9902',
      title: 'Chicken Quinoa Plate',
      description: 'Lean chicken with quinoa and roasted vegetables.',
      ingredients: const ['Chicken breast', 'Quinoa', 'Broccoli', 'Carrots'],
      calories: 560,
      protein: 46,
      carbs: 48,
      fat: 18,
      difficulty: 'medium',
      prepTime: 25,
      tags: const ['Lunch', 'Meal Prep'],
      supportedDiets: const ['balanced', 'high_protein'],
    ),
    Recipe(
      id: '9903',
      title: 'Salmon Greens Dinner',
      description: 'Pan-seared salmon with greens and sweet potato.',
      ingredients: const ['Salmon', 'Spinach', 'Sweet potato', 'Garlic'],
      calories: 610,
      protein: 42,
      carbs: 38,
      fat: 30,
      difficulty: 'medium',
      prepTime: 30,
      tags: const ['Dinner', 'Omega-3'],
      supportedDiets: const ['balanced', 'low_carb'],
    ),
  ];
}

// recipe recommendations based on pantry & profile
final recommendationsProvider = FutureProvider<List<Recipe>>((ref) async {
  final pantry = ref.watch(pantryProvider);
  final profile = ref.watch(dietaryProfileProvider);
  final service = ref.read(recipeServiceProvider);
  final engine = ref.read(recommendationEngineProvider);
  final ingredients = pantry.map((i) => i.name).toList();
  final dietaryPreference = profile['diet_type'] as String?;
  final goals = <String, dynamic>{
    'daily_calories': profile['daily_calorie_target'],
    'daily_protein': profile['daily_protein_target'],
    'daily_carbs': profile['daily_carb_target'],
    'daily_fat': profile['daily_fat_target'],
  };

  try {
    final recipesJson = await service.getPersonalizedRecommendations(
      ingredients: ingredients,
      dietaryPreference: dietaryPreference,
      goals: goals,
    );

    final recipes = recipesJson
        .map((e) {
          try {
            return Recipe.fromJson(e);
          } catch (_) {
            return null;
          }
        })
        .whereType<Recipe>()
        .toList();

    if (recipes.isEmpty) {
      return _fallbackRecipes();
    }

    final ranked = engine.rankAndFilter(
      recipes: recipes,
      pantry: pantry,
      dietaryPreference: dietaryPreference,
      goals: goals,
    );

    return ranked.isEmpty ? _fallbackRecipes() : ranked;
  } catch (_) {
    return _fallbackRecipes();
  }
});

final nutritionSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return const <String, dynamic>{};

  try {
    return await ref.read(analyticsServiceProvider).getNutritionSummary();
  } catch (_) {
    return const <String, dynamic>{};
  }
});

final goalProgressProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return const <String, dynamic>{};

  try {
    return await ref.read(analyticsServiceProvider).getGoalProgress();
  } catch (_) {
    return const <String, dynamic>{};
  }
});

final savedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return const <Recipe>[];

  try {
    final rows = await ref.read(recipeServiceProvider).getSavedRecipes(limit: 100);
    return rows
        .map((row) {
          final nested = row['recipes'];
          if (nested is Map<String, dynamic>) {
            return Recipe.fromJson(nested);
          }
          if (nested is Map) {
            return Recipe.fromJson(Map<String, dynamic>.from(nested));
          }
          return null;
        })
        .whereType<Recipe>()
        .toList();
  } catch (_) {
    return const <Recipe>[];
  }
});

final recommendationEngineProvider =
    Provider.autoDispose((ref) => RecommendationEngine());

final activeMealPlanProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return null;
  return ref.read(mealPlanServiceProvider).getActivePlan();
});

final activeMealPlanItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final plan = await ref.watch(activeMealPlanProvider.future);
  if (plan == null) return const <Map<String, dynamic>>[];
  final planId = plan['id']?.toString();
  if (planId == null || planId.isEmpty) return const <Map<String, dynamic>>[];
  return ref.read(mealPlanServiceProvider).getPlanItems(planId);
});

// ── Saved recipes (favourites) ────────────────────────────────────────────────

class SavedRecipeIdsNotifier extends StateNotifier<Set<String>> {
  SavedRecipeIdsNotifier(this.ref) : super(const {}) {
    _load();
  }

  final Ref ref;

  String? get _uid => supa.Supabase.instance.client.auth.currentUser?.id;

  Future<void> _load() async {
    final userId = _uid;
    if (userId == null) return;

    // Show cached IDs immediately.
    final cached = SessionStorage.loadSavedIds(userId);
    if (cached != null) state = cached;

    // Sync from Supabase in background.
    try {
      final rows = await supa.Supabase.instance.client
          .from('saved_recipes')
          .select('recipe_id')
          .eq('user_id', userId);
      final ids = (rows as List).map((r) => r['recipe_id'] as String).toSet();
      state = ids;
      SessionStorage.saveSavedIds(userId, ids);
    } catch (_) {}
  }

  Future<void> toggle(String recipeId) async {
    final userId = _uid;
    final wasSaved = state.contains(recipeId);
    // Optimistic update.
    state = wasSaved
        ? ({...state}..remove(recipeId))
        : {...state, recipeId};
    try {
      await ref.read(recipeServiceProvider).toggleRecipeSave(recipeId);
      if (userId != null) SessionStorage.saveSavedIds(userId, state);
    } catch (_) {
      // Roll back on failure.
      state = wasSaved
          ? {...state, recipeId}
          : ({...state}..remove(recipeId));
    }
  }

  /// Clear state when user logs out.
  void clear() => state = const {};
}

final savedRecipeIdsProvider =
    StateNotifierProvider<SavedRecipeIdsNotifier, Set<String>>(
  (ref) => SavedRecipeIdsNotifier(ref),
);

// ── Auth helpers ─────────────────────────────────────────────────────────────

/// Maps common Supabase auth error codes to user-friendly messages.
String formatAuthErrorMessage(Object e) {
  if (e is supa.AuthApiException) {
    switch (e.code) {
      case 'email_address_invalid':
        return 'That email address is not valid. Please enter a real email (e.g. name@gmail.com).';
      case 'invalid_credentials':
        return 'Incorrect email or password. Please check and try again.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists. Try logging in instead.';
      case 'weak_password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      case 'email_not_confirmed':
        return 'Please confirm your email address before logging in. Check your inbox.';
      case 'user_not_found':
        return 'No account found with that email. Please register first.';
      default:
        return e.message;
    }
  }

  final raw = e.toString().toLowerCase();
  if (raw.contains('socketexception') ||
      raw.contains('connection refused') ||
      raw.contains('failed host lookup') ||
      raw.contains('timed out') ||
      raw.contains('connection reset')) {
    const configuredSupabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    final effectiveSupabaseUrl = configuredSupabaseUrl.isNotEmpty
        ? configuredSupabaseUrl
        : 'http://127.0.0.1:54321';
    return 'We could not reach the server at $effectiveSupabaseUrl. Confirm SUPABASE_URL / SUPABASE_ANON_KEY are from the same project. For local Supabase use http:// (not https://), and on Android emulator use http://10.0.2.2:54321.';
  }

  if (raw.contains('relation "public.users" does not exist') ||
      raw.contains('relation "public.user_profiles" does not exist') ||
      raw.contains('relation "users" does not exist') ||
      raw.contains('relation "user_profiles" does not exist')) {
    return 'Your Supabase database schema is not initialized. Run migrations, then try again.';
  }

  // Strip the raw Dart exception wrapper so only the message is shown.
  final match = RegExp(r'message:\s*(.+?)(?:,|\))', dotAll: true).firstMatch(e.toString());
  return match?.group(1)?.trim() ?? e.toString();
}

// authentication state
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref),
);

// auth state/logic

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this.ref) : super(const AuthState());

  final Ref ref;

  AuthService get _service => ref.read(authServiceProvider);

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _service.signIn(email, password);
      final supaUser = response.user ?? supa.Supabase.instance.client.auth.currentUser;
      if (supaUser == null) {
        state = state.copyWith(isLoading: false, error: 'Sign in failed. Please try again.');
        return;
      }

      // Ensure app-facing profile row exists in public.user_profiles.
      try {
        final existingProfile = await ref.read(userProfileServiceProvider).getProfile();
        if (existingProfile == null || existingProfile.isEmpty) {
          final fullName = (supaUser.userMetadata?['full_name'] as String?)?.trim() ?? '';
          final parts = fullName.isEmpty ? const <String>[] : fullName.split(RegExp(r'\s+'));
          final firstName = parts.isNotEmpty ? parts.first : null;
          final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

          await ref.read(userProfileServiceProvider).upsertProfile({
            ...?firstName != null ? {'first_name': firstName} : null,
            ...?lastName != null ? {'last_name': lastName} : null,
          });
        }
      } catch (_) {
        // Continue login even if profile bootstrap fails.
      }

      // Fetch user_profiles row so we have the saved first/last name
      Map<String, dynamic>? profile;
      try {
        profile = await ref.read(userProfileServiceProvider).getProfile();
      } catch (_) {}

      final user = User.fromJson({
        'id': supaUser.id,
        'email': supaUser.email ?? email,
        // Supabase user metadata (set during sign-up)
        ...?supaUser.userMetadata,
        // Saved profile fields override metadata
        if (profile != null) ...profile,
      });
      // Cache profile so next cold-start shows data instantly.
      if (profile != null) {
        SessionStorage.saveProfile(supaUser.id, profile);
      }
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: formatAuthErrorMessage(e));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _service.signUp(email, password, fullName: fullName);
      final supaUser = response.user ?? supa.Supabase.instance.client.auth.currentUser;

      if (supaUser == null) {
        state = state.copyWith(
            isLoading: false,
            error: 'Registration failed. Please try again.');
        return;
      }

      // Split full name into first / last
      final parts = fullName.trim().split(' ');
      final firstName = parts.first;
      final lastName =
          parts.length > 1 ? parts.sublist(1).join(' ') : null;

      // Registration always returns to login flow.
      // Persist name metadata when possible, then sign out any auto-session.
      if (response.session != null) {
        try {
          await ref.read(userProfileServiceProvider).upsertProfile({
            'first_name': firstName,
            'last_name': lastName,
          });
        } catch (_) {
          // Profile save failed — not critical, user can provide details after login.
        }
        try {
          await _service.signOut();
        } catch (_) {
          // Ignore sign-out failures; screen flow still redirects to login.
        }
      }

      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        successMessage: response.session == null
            ? 'Account created. Please check your email to confirm your account before logging in.'
            : 'Account created successfully. Please log in with your new credentials.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: formatAuthErrorMessage(e));
    }
  }

  Future<void> logout() async {
    final userId = supa.Supabase.instance.client.auth.currentUser?.id;
    await _service.signOut();
    // Clear the per-user local cache so the next user on this device starts fresh.
    if (userId != null) await SessionStorage.clearUser(userId);
    // Reset in-memory providers.
    ref.read(savedRecipeIdsProvider.notifier).clear();
    state = const AuthState();
  }

  /// Directly set an error message (used for client-side validation feedback).
  void setError(String message) {
    state = state.copyWith(isLoading: false, error: message);
  }

  /// Clear any current error or success message.
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }

  Future<void> updateCurrentUserProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);

    final currentUser = state.user;
    if (currentUser != null) {
      final updatedUser = User.fromJson({
        ...currentUser.toJson(),
        ...data,
      });
      state = state.copyWith(isLoading: false, user: updatedUser);
    }

    try {
      await ref.read(userProfileServiceProvider).upsertProfile(data);
      final userId = supa.Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        SessionStorage.saveProfile(userId, data);
      }
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      final userId = supa.Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        SessionStorage.saveProfile(userId, data);
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Restores the auth user from local cache when the app relaunches with an
  /// existing Supabase session (i.e. the user never explicitly logged out).
  Future<void> restoreSession(supa.User supaUser) async {
    if (state.user != null) return; // already populated this session

    // Show cached profile synchronously.
    final cached = SessionStorage.loadProfile(supaUser.id);
    if (cached != null && cached.isNotEmpty) {
      state = state.copyWith(
        user: User.fromJson({
          'id': supaUser.id,
          'email': supaUser.email ?? '',
          ...?supaUser.userMetadata,
          ...cached,
        }),
      );
    }

    // Refresh from Supabase in background.
    try {
      final profile = await ref.read(userProfileServiceProvider).getProfile();
      if (profile != null && profile.isNotEmpty) {
        state = state.copyWith(
          user: User.fromJson({
            'id': supaUser.id,
            'email': supaUser.email ?? '',
            ...?supaUser.userMetadata,
            ...profile,
          }),
        );
        SessionStorage.saveProfile(supaUser.id, profile);
      }
    } catch (_) {}
  }
}


// Additional providers (e.g. user profile, meals list, recipes) will be
// defined in `models.dart` once data classes are created.
