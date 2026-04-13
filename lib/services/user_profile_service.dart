import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── user_profiles ─────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    return await _supabase
        .from('user_profiles')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> upsertProfile(
      Map<String, dynamic> data) async {
    return await _supabase
        .from('user_profiles')
        .upsert({...data, 'user_id': _userId})
        .select()
        .single();
  }

  // Convenience wrappers kept for backward compat with screens
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> profileData) =>
      upsertProfile(profileData);

  Future<Map<String, dynamic>> getNutritionGoals() async {
    final row = await getProfile();
    return {
      'daily_calorie_target': row?['daily_calorie_target'],
      'daily_protein_target': row?['daily_protein_target'],
      'daily_carb_target': row?['daily_carb_target'],
      'daily_fat_target': row?['daily_fat_target'],
    };
  }

  Future<Map<String, dynamic>> updateGoals(
      Map<String, dynamic> goals) =>
      upsertProfile({
        'daily_calorie_target': goals['daily_calorie_target'] ?? goals['target_calories'],
        'daily_protein_target': goals['daily_protein_target'] ?? goals['target_protein'],
        'daily_carb_target': goals['daily_carb_target'] ?? goals['target_carbs'],
        'daily_fat_target': goals['daily_fat_target'] ?? goals['target_fat'],
      });

  // ── dietary_preferences ───────────────────────────────────

  Future<Map<String, dynamic>?> getDietaryPreferences() async {
    return await _supabase
        .from('dietary_preferences')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> upsertDietaryPreferences(
      Map<String, dynamic> prefs) async {
    return await _supabase
        .from('dietary_preferences')
        .upsert({...prefs, 'user_id': _userId})
        .select()
        .single();
  }

  Future<Map<String, dynamic>> updatePreferences(
      Map<String, dynamic> preferences) =>
      upsertDietaryPreferences(preferences);

  Future<Map<String, dynamic>> getDietaryRestrictions() async {
    final row = await getDietaryPreferences();
    return {'restrictions': row?['excluded_ingredients'] ?? []};
  }

  Future<Map<String, dynamic>> updateDietaryRestrictions(
      List<String> restrictions) =>
      upsertDietaryPreferences({'excluded_ingredients': restrictions});

  Future<Map<String, dynamic>> getAllergies() async {
    final row = await getDietaryPreferences();
    return {'allergies': row?['allergies'] ?? []};
  }

  Future<Map<String, dynamic>> updateAllergies(
      List<String> allergies) =>
      upsertDietaryPreferences({'allergies': allergies});

  Future<Map<String, dynamic>> getActivityLevel() async {
    final row = await getProfile();
    return {'activity_level': row?['activity_level']};
  }

  Future<Map<String, dynamic>> updateActivityLevel(
      String activityLevel) =>
      upsertProfile({'activity_level': activityLevel});

  Future<Map<String, dynamic>> updateHealthInfo(
      Map<String, dynamic> healthInfo) =>
      upsertProfile(healthInfo);

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
              }
            ]
          : [],
    };
  }

  Future<Map<String, dynamic>> addWeightEntry(double weight,
      {DateTime? date}) =>
      upsertProfile({'weight': weight});

  Future<void> deleteWeightEntry(int entryId) async {
    // No-op: weight is a single column on user_profiles
  }

  Future<Map<String, dynamic>> calculateDailyCalories() =>
      getNutritionGoals();

  @Deprecated('Use getDietaryPreferences() instead')
  Future<Map<String, dynamic>> updatePreferencesLegacy(
      Map<String, dynamic> prefs) =>
      upsertDietaryPreferences(prefs);

}