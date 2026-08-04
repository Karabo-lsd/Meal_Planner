bool hasCompleteOnboardingProfile(Map<String, dynamic> profile) {
  final firstName = (profile['first_name'] as String?)?.trim();
  final age = profile['age'];
  final height = profile['height'];
  final weight = profile['weight'];
  final goal = (profile['goal'] as String?)?.trim();
  final dailyCalories = profile['daily_calorie_target'];
  final dietType = (profile['diet_type'] as String?)?.trim();

  return firstName != null &&
      firstName.isNotEmpty &&
      age != null &&
      age is num &&
      age > 0 &&
      height != null &&
      height is num &&
      height > 0 &&
      weight != null &&
      weight is num &&
      weight > 0 &&
      goal != null &&
      goal.isNotEmpty &&
      dailyCalories != null &&
      dailyCalories is num &&
      dailyCalories > 0 &&
      dietType != null &&
      dietType.isNotEmpty;
}

bool shouldPromptForProfileSetup(Map<String, dynamic> profile) {
  return !hasCompleteOnboardingProfile(profile);
}
