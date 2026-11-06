import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String _defaultLocalBaseUrl = 'http://127.0.0.1:8000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    return resolveBaseUrl(
      isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      compileTimeUrl: _configuredBaseUrl,
      dotenvUrl: dotenv.maybeGet('API_BASE_URL') ?? '',
    );
  }

  /// Ordered backends to try: USB (adb reverse) first, then the PC's Wi-Fi URL.
  /// --dart-define=API_WIFI_URL=http://PC-IP:8000
  /// or API_WIFI_URL in .env.
  static List<String> get baseUrlCandidates {
    return resolveCandidates(
      primary: baseUrl,
      wifiUrl: _usbOnly
          ? ''
          : (_configuredWifiUrl.trim().isNotEmpty
                ? _configuredWifiUrl
                : (dotenv.maybeGet('API_WIFI_URL') ?? '')),
    );
  }

  // --dart-define=API_USB_ONLY=true disables the Wi-Fi fallback.
  static const bool _usbOnly = bool.fromEnvironment('API_USB_ONLY');

  static const String _configuredWifiUrl = String.fromEnvironment(
    'API_WIFI_URL',
    defaultValue: '',
  );

  @visibleForTesting
  static List<String> resolveCandidates({
    required String primary,
    required String wifiUrl,
  }) {
    final urls = <String>[primary.trim()];
    final wifi = wifiUrl.trim();
    if (wifi.isNotEmpty && !urls.contains(wifi)) urls.add(wifi);
    return urls;
  }

  @visibleForTesting
  static String resolveBaseUrl({
    required bool isAndroid,
    required String compileTimeUrl,
    required String dotenvUrl,
  }) {
    final configuredUrl = compileTimeUrl.trim();
    if (configuredUrl.isNotEmpty) return configuredUrl;

    if (isAndroid) {
      // Use USB reverse by default, or an explicit Wi-Fi URL from dart-define.
      return _defaultLocalBaseUrl;
    }

    final environmentUrl = dotenvUrl.trim();
    if (environmentUrl.isNotEmpty) return environmentUrl;

    return _defaultLocalBaseUrl;
  }

  // App Settings
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 60000;
  static const int maxRetries = 1;

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
