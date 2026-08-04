import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _defaultLocalBaseUrl = 'http://127.0.0.1:8000';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.spoonacular.com');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator localhost points to the emulator itself.
      return _androidEmulatorBaseUrl;
    }

    return _defaultLocalBaseUrl;
  }

  static const String apiVersion = 'v1';

  /// Spoonacular API key — injected at build time via --dart-define.
  static const String spoonacularApiKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
    defaultValue: '0b93fe311e1c455cbbd51107398d16e5',
  );

  static bool get hasSpoonacularApiKey => spoonacularApiKey.trim().isNotEmpty;

  static String get apiBaseUrl => '$baseUrl/$apiVersion';

  // Authentication Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';

  // User Profile Endpoints
  static const String profile = '/users/me';

  // Meal Endpoints
  static const String meals = '/meals';
  static const String analyzeMeal = '/meals/analyze';

  // Recipe Endpoints
  static const String recipes = '/recipes';

  // Analytics Endpoints
  static const String analyticsNutrition = '/analytics/nutrition';
  static const String analyticsMealFrequency = '/analytics/meal-frequency';
  static const String analyticsProgress = '/analytics/progress';
  static const String analyticsGoals = '/analytics/goals';
  static const String analyticsWeekly = '/analytics/weekly';
  static const String analyticsMonthly = '/analytics/monthly';
  static const String analyticsInsights = '/analytics/insights';
  static const String analyticsCalories = '/analytics/calories';
  static const String analyticsMacros = '/analytics/macros';

  // Ingredient Endpoints
  static const String ingredients = '/ingredients';

  // Voice Endpoints
  static const String voiceTranscribe = '/voice/transcribe';
  static const String voiceCommand = '/voice/command';
  static const String voiceIngredients = '/voice/ingredients';
  static const String voiceSettings = '/voice/settings';

  // App Settings
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int maxRetries = 3;

  // Image Settings
  static const int maxImageSize = 1024 * 1024; // 1MB
  static const double imageQuality = 0.8;

  // Cache Settings
  static const Duration cacheDuration = Duration(hours: 24);
  static const int maxCacheSize = 100;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
}