import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

// services
import '../services/services.dart';
import '../services/recommendation_service.dart';
// models
import 'friendly_error.dart';
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
final mealPlanServiceProvider = Provider.autoDispose(
  (ref) => MealPlanService(),
);
final recipeServiceProvider = Provider.autoDispose((ref) => RecipeService());
final analyticsServiceProvider = Provider.autoDispose(
  (ref) => AnalyticsService(),
);
final userProfileServiceProvider = Provider.autoDispose(
  (ref) => UserProfileService(),
);
final ingredientServiceProvider = Provider.autoDispose(
  (ref) => IngredientService(),
);
final foodScanServiceProvider = Provider.autoDispose(
  (ref) => FoodScanService(
    mealService: ref.read(mealServiceProvider),
    ingredientService: ref.read(ingredientServiceProvider),
  ),
);
final providerBootstrapEnabledProvider = Provider<bool>((ref) => true);
final integrationRegistryProvider = Provider((ref) => IntegrationRegistry());
final recommendationServiceProvider = Provider<RecommendationService>(
  (ref) => RecommendationService(),
);

// ── Supabase ─────────────────────────────────────────────────────────────────
final supabaseProvider = Provider<supa.SupabaseClient>(
  (_) => supa.Supabase.instance.client,
);

/// Streams every Supabase auth event (sign-in, sign-out, token refresh).
/// Watch this in main.dart for auth-based routing.
final supabaseAuthStreamProvider = StreamProvider<supa.AuthState>(
  (ref) => supa.Supabase.instance.client.auth.onAuthStateChange,
);

/// The currently authenticated Supabase user, or null when signed out.
final currentSupabaseUserProvider = Provider<supa.User?>((ref) {
  ref.watch(supabaseAuthStreamProvider);
  return supa.Supabase.instance.client.auth.currentUser;
});

/// Id of the signed-in user. Per-user providers watch this so their state is
/// rebuilt from scratch whenever a different user signs in or out.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(supabaseAuthStreamProvider);
  return supa.Supabase.instance.client.auth.currentUser?.id;
});

/// True once the signed-in user's saved profile satisfies the onboarding
/// requirements. Reads from Supabase so a new user always starts from zero.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  return ref.read(dietaryProfileProvider.notifier).ensureLoaded();
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
    state = state
        .where((i) => i.id != ingredient.id || i.name != ingredient.name)
        .toList();
    _persistPantry();
  }

  void _persistPantry() {
    final userId = _uid;
    if (userId == null) return;
    final raw = state
        .map((i) => i.toJson()..['ingredient_name_raw'] ??= i.name)
        .toList();
    SessionStorage.savePantry(userId, raw.cast<Map<String, dynamic>>());
  }
}

final pantryProvider = StateNotifierProvider<PantryNotifier, List<Ingredient>>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return PantryNotifier(ref);
});

// dietary profile stored separately
final dietaryProfileProvider =
    StateNotifierProvider<DietaryProfileNotifier, Map<String, dynamic>>((ref) {
      ref.watch(currentUserIdProvider);
      return DietaryProfileNotifier(ref);
    });

class DietaryProfileNotifier extends StateNotifier<Map<String, dynamic>> {
  DietaryProfileNotifier(this.ref) : super({}) {
    if (ref.read(providerBootstrapEnabledProvider)) {
      _loadProfile();
    }
  }

  final Ref ref;

  String? get _uid => supa.Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadProfile({bool throwOnError = false}) async {
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
        if (prefs['allergies'] != null) 'allergies': prefs['allergies'],
        if (prefs['excluded_ingredients'] != null)
          'excluded_ingredients': prefs['excluded_ingredients'],
        'preferences': {
          ...(profile['preferences'] is Map
              ? Map<String, dynamic>.from(profile['preferences'] as Map)
              : const <String, dynamic>{}),
          if (prefs['diet_type'] != null) 'diet': prefs['diet_type'],
        },
      };

      if (!mounted || _uid != userId) return;
      state = fresh;
      SessionStorage.saveProfile(userId, fresh);
    } catch (_) {
      if (throwOnError) rethrow;
    }
  }

  /// Loads the profile from Supabase and reports whether onboarding is done.
  /// Falls back to the cached profile only when the network is unavailable.
  Future<bool> ensureLoaded() async {
    await Future<void>.delayed(Duration.zero);
    if (hasCompletedOnboarding()) return true;

    try {
      await _loadProfile(throwOnError: true);
    } catch (_) {
      if (!hasCompletedOnboarding()) rethrow;
    }
    return hasCompletedOnboarding();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = _uid;
    if (userId == null) {
      throw StateError('You must be signed in to save your dietary profile.');
    }

    final mergedProfile = <String, dynamic>{...state};

    if (data['preferences'] is Map && mergedProfile['preferences'] is Map) {
      mergedProfile['preferences'] = {
        ...Map<String, dynamic>.from(mergedProfile['preferences'] as Map),
        ...Map<String, dynamic>.from(data['preferences'] as Map),
      };
    } else if (data['preferences'] is Map) {
      mergedProfile['preferences'] = Map<String, dynamic>.from(
        data['preferences'] as Map,
      );
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
    await SessionStorage.saveProfile(userId, state);

    try {
      final serverProfile = await ref
          .read(userProfileServiceProvider)
          .updateProfile(data, expectedUserId: userId);
      if (!mounted || _uid != userId) return;
      if (serverProfile.isNotEmpty) {
        state = {...mergedProfile, ...serverProfile};
        await SessionStorage.saveProfile(userId, state);
      }
      ref.invalidate(recommendationsProvider);
      ref.invalidate(recipeSearchProvider);
      ref.read(recipePageProvider.notifier).state = 0;
      ref.invalidate(recipeFeedProvider);
    } catch (_) {
      // Keep the locally updated profile so the app feels responsive even when
      // the backend is unavailable.
      rethrow;
    }
  }

  bool hasCompletedOnboarding() => hasCompleteOnboardingProfile(state);
}

// AI-ranked recipes for the signed-in user. The backend loads the profile,
// diet, allergies and pantry from Supabase and retrieves Spoonacular/Supabase
// candidates before OpenAI ranks them.
Recipe? _recipeFromRecommendation(Map<String, dynamic> item) {
  final raw = item['recipe'];
  if (raw is! Map) {
    debugPrint('Recommendation item did not include a recipe object.');
    return null;
  }
  try {
    return Recipe.fromJson(Map<String, dynamic>.from(raw));
  } catch (error) {
    debugPrint('Could not parse a recommended recipe: $error');
    return null;
  }
}

/// Zero-based page of recommendations (50 recipes per page) shown on Home.
final recipePageProvider = StateProvider<int>((ref) => 0);

/// Backend allows pages 0-8 (Spoonacular offset limit).
const int maxRecipePage = 17;

final recommendationsProvider = FutureProvider<List<Recipe>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <Recipe>[];
  final page = ref.watch(recipePageProvider);

  final items = await ref
      .read(recommendationServiceProvider)
      .recommend(
        userId: userId,
        requestType: 'search',
        limit: 50,
        page: page,
      );
  final recipes = items
      .map(_recipeFromRecommendation)
      .whereType<Recipe>()
      .toList();
  debugPrint(
    'Recipe recommendations: received ${items.length} items; parsed ${recipes.length}.',
  );
  return recipes;
});

/// Instructions and exact ingredient amounts for a recipe (empty when unavailable).
final recipeDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      try {
        return await RecommendationService().recipeDetails(id);
      } catch (_) {
        return const <String, dynamic>{};
      }
    });

/// Foods the user has logged as eaten today.
final todayLogsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <Map<String, dynamic>>[];
  return ref.read(mealServiceProvider).getLogs(date: DateTime.now());
});

/// AI-assisted recipe search for a free-text query.
final recipeSearchProvider = FutureProvider.autoDispose
    .family<List<Recipe>, String>((ref, query) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null || query.trim().isEmpty) return const <Recipe>[];
      final page = ref.watch(recipePageProvider);
      final items = await ref
          .read(recommendationServiceProvider)
          .recommend(
            userId: userId,
            requestType: 'search',
            query: query,
            limit: 50,
            page: page,
          );
      return items.map(_recipeFromRecommendation).whereType<Recipe>().toList();
    });

// ── Paginated recipe catalog feed (backs "load more" browsing on Home) ──────
class RecipeFeedState {
  const RecipeFeedState({
    this.items = const <Recipe>[],
    this.nextSkip = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<Recipe> items;
  final int nextSkip;
  final bool hasMore;
  final bool isLoadingMore;

  RecipeFeedState copyWith({
    List<Recipe>? items,
    int? nextSkip,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return RecipeFeedState(
      items: items ?? this.items,
      nextSkip: nextSkip ?? this.nextSkip,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class RecipeFeedNotifier extends StateNotifier<RecipeFeedState> {
  RecipeFeedNotifier(this.ref) : super(const RecipeFeedState());

  static const _pageSize = 20;
  final Ref ref;

  /// Seeds the feed with the initial (curated/personalized) batch so the
  /// grid has something to show before the user requests more pages.
  void seedInitial(List<Recipe> initial) {
    // Replace stale cached/provider results when recommendations refresh.
    // The recommendation batch is complete and profile-filtered.
    state = state.copyWith(
      items: _dedupe(initial),
      nextSkip: 0,
      hasMore: false,
      isLoadingMore: false,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final rows = await ref
          .read(recipeServiceProvider)
          .getRecipes(skip: state.nextSkip, limit: _pageSize);
      final fetched = rows
          .map((e) {
            try {
              return Recipe.fromJson(e);
            } catch (_) {
              return null;
            }
          })
          .whereType<Recipe>()
          .toList();

      state = state.copyWith(
        items: _dedupe([...state.items, ...fetched]),
        isLoadingMore: false,
        hasMore: fetched.length == _pageSize,
        nextSkip: state.nextSkip + _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
    }
  }

  void reset() {
    state = const RecipeFeedState();
  }

  List<Recipe> _dedupe(List<Recipe> recipes) {
    final seen = <String>{};
    return recipes.where((r) => seen.add(r.id)).toList();
  }
}

final recipeFeedProvider =
    StateNotifierProvider.autoDispose<RecipeFeedNotifier, RecipeFeedState>((
      ref,
    ) {
      ref.watch(currentUserIdProvider);
      return RecipeFeedNotifier(ref);
    });

final nutritionSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(currentUserIdProvider);
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return const <String, dynamic>{};

  try {
    return await ref.read(analyticsServiceProvider).getNutritionSummary();
  } catch (_) {
    return const <String, dynamic>{};
  }
});

final goalProgressProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(currentUserIdProvider);
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return const <String, dynamic>{};

  try {
    return await ref.read(analyticsServiceProvider).getGoalProgress();
  } catch (_) {
    return const <String, dynamic>{};
  }
});

final savedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.watch(currentUserIdProvider);
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return const <Recipe>[];

  final rows = await ref
      .read(recipeServiceProvider)
      .getSavedRecipes(limit: 100);
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
});

final recommendationEngineProvider = Provider.autoDispose(
  (ref) => RecommendationEngine(),
);

final activeMealPlanProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  ref.watch(currentUserIdProvider);
  final currentUser = supa.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return null;
  return ref.read(mealPlanServiceProvider).getActivePlan();
});

final activeMealPlanItemsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
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
    state = wasSaved ? ({...state}..remove(recipeId)) : {...state, recipeId};
    try {
      await ref.read(recipeServiceProvider).toggleRecipeSave(recipeId);
      if (userId != null) SessionStorage.saveSavedIds(userId, state);
    } catch (_) {
      // Roll back on failure.
      state = wasSaved ? {...state, recipeId} : ({...state}..remove(recipeId));
      rethrow;
    }
  }

  /// Clear state when user logs out.
  void clear() => state = const {};
}

final savedRecipeIdsProvider =
    StateNotifierProvider<SavedRecipeIdsNotifier, Set<String>>((ref) {
      ref.watch(currentUserIdProvider);
      return SavedRecipeIdsNotifier(ref);
    });

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
        return 'Something went wrong. Please try again.';
    }
  }

  final raw = e.toString().toLowerCase();
  if (raw.contains('socketexception') ||
      raw.contains('connection refused') ||
      raw.contains('failed host lookup') ||
      raw.contains('timed out') ||
      raw.contains('connection reset')) {
    return 'Service not available right now. Please check your connection and try again.';
  }

  if (raw.contains('relation "public.users" does not exist') ||
      raw.contains('relation "public.user_profiles" does not exist') ||
      raw.contains('relation "users" does not exist') ||
      raw.contains('relation "user_profiles" does not exist')) {
    return 'This service is not available right now. Please try again later.';
  }

  return 'Something went wrong. Please try again.';
}

// authentication state
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref),
);

// auth state/logic

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this.ref) : super(const AuthState());

  final Ref ref;
  Timer? _messageTimer;

  // Errors and confirmations fade out on their own.
  @override
  set state(AuthState value) {
    final previous = mounted ? super.state : value;
    super.state = value;
    final hasMessage = value.error != null || value.successMessage != null;
    if (!hasMessage) {
      _messageTimer?.cancel();
    } else if (value.error != previous.error ||
        value.successMessage != previous.successMessage) {
      _messageTimer?.cancel();
      _messageTimer = Timer(
        value.error != null ? _errorDuration : _successDuration,
        () {
          if (mounted) clearMessages();
        },
      );
    }
  }

  static const _errorDuration = Duration(seconds: 5);
  static const _successDuration = Duration(seconds: 6);

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  AuthService get _service => ref.read(authServiceProvider);

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _service.signIn(email, password);
      final supaUser =
          response.user ?? supa.Supabase.instance.client.auth.currentUser;
      if (supaUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign in failed. Please try again.',
        );
        return;
      }

      // Ensure app-facing profile row exists in public.user_profiles.
      try {
        final existingProfile = await ref
            .read(userProfileServiceProvider)
            .getProfile();
        if (existingProfile == null || existingProfile.isEmpty) {
          final fullName =
              (supaUser.userMetadata?['full_name'] as String?)?.trim() ?? '';
          final parts = fullName.isEmpty
              ? const <String>[]
              : fullName.split(RegExp(r'\s+'));
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

      final user = User.fromAuth(
        id: supaUser.id,
        email: supaUser.email ?? email,
        metadata: supaUser.userMetadata,
        profile: profile,
      );
      // Cache profile so next cold-start shows data instantly.
      if (profile != null) {
        SessionStorage.saveProfile(supaUser.id, profile);
      }
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: formatAuthErrorMessage(e),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      await _service.sendPasswordReset(email);
      state = state.copyWith(
        isLoading: false,
        successMessage:
            'If an account exists for that email, a password reset link is on its way.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: formatAuthErrorMessage(e),
      );
    }
  }

  Future<void> signInWithGoogle() =>
      _signInWithProvider(_service.signInWithGoogle, providerName: 'Google');

  Future<void> signInWithApple() =>
      _signInWithProvider(_service.signInWithApple, providerName: 'Apple');

  Future<void> _signInWithProvider(
    Future<bool> Function() signIn, {
    required String providerName,
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      final launched = await signIn();
      state = state.copyWith(
        isLoading: false,
        error: launched ? null : '$providerName sign-in could not be opened.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: formatAuthErrorMessage(e),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _service.signUp(
        email,
        password,
        fullName: fullName,
      );
      final supaUser =
          response.user ?? supa.Supabase.instance.client.auth.currentUser;

      if (supaUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Registration failed. Please try again.',
        );
        return;
      }

      // Split full name into first / last
      final parts = fullName.trim().split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

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
      if (response.session == null) {
        await SessionStorage.savePendingVerificationEmail(email.trim());
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: formatAuthErrorMessage(e),
      );
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

  Future<void> deleteAccount() async {
    final userId = supa.Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to delete your account.');
    }

    await _service.deleteAccount();
    try {
      await _service.signOutLocally();
    } finally {
      ref.read(savedRecipeIdsProvider.notifier).clear();
      state = const AuthState();
      await SessionStorage.clearUser(userId);
    }
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
    final currentUser = state.user;
    final previousState = state;
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (currentUser == null ||
          supa.Supabase.instance.client.auth.currentUser?.id !=
              currentUser.id) {
        throw StateError(
          'The signed-in user changed while saving the profile.',
        );
      }
      final userId = currentUser.id;
      final updatedUser = User.fromJson({...currentUser.toJson(), ...data});
      state = state.copyWith(isLoading: false, user: updatedUser);

      await ref
          .read(userProfileServiceProvider)
          .updateProfile(data, expectedUserId: userId);
      if (supa.Supabase.instance.client.auth.currentUser?.id != userId ||
          state.user?.id != userId) {
        return;
      }
      SessionStorage.saveProfile(userId, {
        ...?SessionStorage.loadProfile(userId),
        ...data,
      });
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      if (currentUser == null ||
          (supa.Supabase.instance.client.auth.currentUser?.id ==
                  currentUser.id &&
              state.user?.id == currentUser.id)) {
        state = previousState.copyWith(
          isLoading: false,
          error: friendlyErrorMessage(e, action: 'save your profile'),
        );
      }
      rethrow;
    }
  }

  /// Restores the auth user from local cache when the app relaunches with an
  /// existing Supabase session (i.e. the user never explicitly logged out).
  Future<void> restoreSession(supa.User supaUser) async {
    if (supa.Supabase.instance.client.auth.currentUser?.id != supaUser.id) {
      return;
    }
    if (state.belongsToUser(supaUser.id)) return;

    // Show cached profile synchronously.
    final cached = SessionStorage.loadProfile(supaUser.id);
    state = AuthState(
      user: User.fromAuth(
        id: supaUser.id,
        email: supaUser.email ?? '',
        metadata: supaUser.userMetadata,
        profile: cached,
      ),
    );

    // Refresh from Supabase in background.
    try {
      final profile = await ref.read(userProfileServiceProvider).getProfile();
      if (supa.Supabase.instance.client.auth.currentUser?.id != supaUser.id ||
          state.user?.id != supaUser.id) {
        return;
      }
      if (profile != null && profile.isNotEmpty) {
        state = state.copyWith(
          user: User.fromAuth(
            id: supaUser.id,
            email: supaUser.email ?? '',
            metadata: supaUser.userMetadata,
            profile: profile,
          ),
        );
        SessionStorage.saveProfile(supaUser.id, profile);
      }
    } catch (_) {}
  }
}

// Additional providers (e.g. user profile, meals list, recipes) will be
// defined in `models.dart` once data classes are created.
