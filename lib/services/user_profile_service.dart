import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileService {
  final _supabase = Supabase.instance.client;

  static const _profileColumns = {
    'first_name',
    'last_name',
    'phone',
    'age',
    'sex',
    'weight',
    'height',
    'activity_level',
    'goal',
    'daily_calorie_target',
    'daily_protein_target',
    'daily_carb_target',
    'daily_fat_target',
  };

  static const _dietaryColumns = {
    'diet_type',
    'allergies',
    'excluded_ingredients',
    'preferred_cuisines',
    'disliked_foods',
    'max_prep_time_minutes',
    'budget_preference',
  };

  User? get _currentUser => _supabase.auth.currentUser;

  String _userIdOrThrow() {
    final user = _currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save your dietary profile.');
    }
    return user.id;
  }

  Future<void> _ensureUserRow(String userId) async {
    final currentUser = _currentUser;
    if (currentUser == null || currentUser.id != userId) {
      throw StateError('The signed-in user changed while saving the profile.');
    }

    await _supabase
        .from('users')
        .upsert({'id': userId, 'email': currentUser.email ?? ''})
        .select()
        .single();
  }

  // ── user_profiles ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _currentUser;
    if (user == null) return null;

    return _getProfileForUser(user.id);
  }

  Future<Map<String, dynamic>?> _getProfileForUser(String userId) async {
    if (_currentUser?.id != userId) {
      throw StateError('The signed-in user changed while loading the profile.');
    }
    return await _supabase
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> upsertProfile(Map<String, dynamic> data) async {
    final userId = _userIdOrThrow();
    return _upsertProfileForUser(userId, data);
  }

  Future<Map<String, dynamic>> _upsertProfileForUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _ensureUserRow(userId);
    if (_currentUser?.id != userId) {
      throw StateError('The signed-in user changed while saving the profile.');
    }
    return await _supabase
        .from('user_profiles')
        .upsert({...data, 'user_id': userId}, onConflict: 'user_id')
        .select()
        .single();
  }

  // Convenience wrapper kept for backward compat with screens.
  // Supports legacy nested payloads: { preferences: {...}, goals: {...} }
  // and maps them to user_profiles + dietary_preferences tables.
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData, {
    String? expectedUserId,
  }) async {
    final userId = expectedUserId ?? _userIdOrThrow();
    if (_currentUser?.id != userId) {
      throw StateError('The signed-in user changed while saving the profile.');
    }
    final payload = Map<String, dynamic>.from(profileData);
    final nestedPreferences = payload.remove('preferences');
    final nestedGoals = payload.remove('goals');

    final profileUpdates = <String, dynamic>{...payload};
    final preferenceUpdates = <String, dynamic>{};

    for (final key in _dietaryColumns) {
      if (profileUpdates.containsKey(key)) {
        preferenceUpdates[key] = profileUpdates.remove(key);
      }
    }

    if (nestedPreferences is Map) {
      final preferences = Map<String, dynamic>.from(nestedPreferences);
      final diet = preferences['diet'];
      if (diet is String && diet.trim().isNotEmpty) {
        preferenceUpdates['diet_type'] = diet.trim();
      }
    }

    if (nestedGoals is Map) {
      final goals = Map<String, dynamic>.from(nestedGoals);

      final dailyCalories = _asDouble(
        goals['daily_calories'] ??
            goals['daily_calorie_target'] ??
            goals['target_calories'],
      );

      if (dailyCalories != null) {
        profileUpdates['daily_calorie_target'] = dailyCalories;
      }

      profileUpdates['daily_protein_target'] = _macroTargetFrom(
        goals: goals,
        calories: dailyCalories,
        ratioKeys: const ['protein_ratio'],
        targetKeys: const ['daily_protein_target', 'target_protein'],
        caloriesPerGram: 4,
      );

      profileUpdates['daily_carb_target'] = _macroTargetFrom(
        goals: goals,
        calories: dailyCalories,
        ratioKeys: const ['carb_ratio'],
        targetKeys: const ['daily_carb_target', 'target_carbs'],
        caloriesPerGram: 4,
      );

      profileUpdates['daily_fat_target'] = _macroTargetFrom(
        goals: goals,
        calories: dailyCalories,
        ratioKeys: const ['fat_ratio'],
        targetKeys: const ['daily_fat_target', 'target_fat'],
        caloriesPerGram: 9,
      );
    }

    if (profileUpdates['daily_calories'] != null &&
        profileUpdates['daily_calorie_target'] == null) {
      profileUpdates['daily_calorie_target'] = _asDouble(
        profileUpdates.remove('daily_calories'),
      );
    }

    profileUpdates.removeWhere(
      (key, value) => value == null || !_profileColumns.contains(key),
    );
    preferenceUpdates.removeWhere((_, value) => value == null);

    final profileRow = profileUpdates.isNotEmpty
        ? await _upsertProfileForUser(userId, profileUpdates)
        : (await _getProfileForUser(userId) ?? <String, dynamic>{});

    Map<String, dynamic>? dietaryRow;
    if (preferenceUpdates.isNotEmpty) {
      dietaryRow = await _upsertDietaryPreferencesForUser(
        userId,
        preferenceUpdates,
      );
    }

    return {
      ...profileRow,
      if (dietaryRow != null) ...dietaryRow,
      if (preferenceUpdates['diet_type'] != null)
        'diet_type': preferenceUpdates['diet_type'],
    };
  }

  Future<Map<String, dynamic>> getNutritionGoals() async {
    final row = await getProfile();
    return {
      'daily_calorie_target': row?['daily_calorie_target'],
      'daily_protein_target': row?['daily_protein_target'],
      'daily_carb_target': row?['daily_carb_target'],
      'daily_fat_target': row?['daily_fat_target'],
    };
  }

  Future<Map<String, dynamic>> updateGoals(Map<String, dynamic> goals) =>
      upsertProfile({
        'daily_calorie_target':
            goals['daily_calorie_target'] ?? goals['target_calories'],
        'daily_protein_target':
            goals['daily_protein_target'] ?? goals['target_protein'],
        'daily_carb_target':
            goals['daily_carb_target'] ?? goals['target_carbs'],
        'daily_fat_target': goals['daily_fat_target'] ?? goals['target_fat'],
      });

  // ── dietary_preferences ───────────────────────────────────

  Future<Map<String, dynamic>?> getDietaryPreferences() async {
    final user = _currentUser;
    if (user == null) return null;

    return await _supabase
        .from('dietary_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> upsertDietaryPreferences(
    Map<String, dynamic> prefs,
  ) async {
    final userId = _userIdOrThrow();
    return _upsertDietaryPreferencesForUser(userId, prefs);
  }

  Future<Map<String, dynamic>> _upsertDietaryPreferencesForUser(
    String userId,
    Map<String, dynamic> prefs,
  ) async {
    await _ensureUserRow(userId);
    if (_currentUser?.id != userId) {
      throw StateError('The signed-in user changed while saving preferences.');
    }
    return await _supabase
        .from('dietary_preferences')
        .upsert({...prefs, 'user_id': userId}, onConflict: 'user_id')
        .select()
        .single();
  }

  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> preferences,
  ) => upsertDietaryPreferences(preferences);

  Future<Map<String, dynamic>> getDietaryRestrictions() async {
    final row = await getDietaryPreferences();
    return {'restrictions': row?['excluded_ingredients'] ?? []};
  }

  Future<Map<String, dynamic>> updateDietaryRestrictions(
    List<String> restrictions,
  ) => upsertDietaryPreferences({'excluded_ingredients': restrictions});

  Future<Map<String, dynamic>> getAllergies() async {
    final row = await getDietaryPreferences();
    return {'allergies': row?['allergies'] ?? []};
  }

  Future<Map<String, dynamic>> updateAllergies(List<String> allergies) =>
      upsertDietaryPreferences({'allergies': allergies});

  Future<Map<String, dynamic>> getActivityLevel() async {
    final row = await getProfile();
    return {'activity_level': row?['activity_level']};
  }

  Future<Map<String, dynamic>> updateActivityLevel(String activityLevel) =>
      upsertProfile({'activity_level': activityLevel});

  Future<Map<String, dynamic>> updateHealthInfo(
    Map<String, dynamic> healthInfo,
  ) => upsertProfile(healthInfo);

  /// Weight history is not a separate table in Supabase — weight is stored
  /// directly on user_profiles. Return a single-entry list for compat.
  Future<Map<String, dynamic>> getWeightHistory({int limit = 30}) async {
    final row = await getProfile();
    final weight = row?['weight'];
    return {
      'items': weight != null
          ? [
              {
                'weight': weight,
                'date': DateTime.now().toIso8601String().split('T')[0],
              },
            ]
          : [],
    };
  }

  Future<Map<String, dynamic>> addWeightEntry(
    double weight, {
    DateTime? date,
  }) => upsertProfile({'weight': weight});

  Future<void> deleteWeightEntry(int entryId) async {
    // No-op: weight is a single column on user_profiles
  }

  Future<Map<String, dynamic>> calculateDailyCalories() => getNutritionGoals();

  @Deprecated('Use getDietaryPreferences() instead')
  Future<Map<String, dynamic>> updatePreferencesLegacy(
    Map<String, dynamic> prefs,
  ) => upsertDietaryPreferences(prefs);

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double? _macroTargetFrom({
    required Map<String, dynamic> goals,
    required double? calories,
    required List<String> ratioKeys,
    required List<String> targetKeys,
    required int caloriesPerGram,
  }) {
    for (final key in targetKeys) {
      final direct = _asDouble(goals[key]);
      if (direct != null) {
        return direct;
      }
    }

    if (calories == null || calories <= 0) {
      return null;
    }

    for (final key in ratioKeys) {
      final ratio = _asDouble(goals[key]);
      if (ratio != null) {
        return (calories * (ratio / 100.0)) / caloriesPerGram;
      }
    }

    return null;
  }
}
