import 'package:flutter_test/flutter_test.dart';
import 'package:meal_planning_app/core/config/app_config.dart';

void main() {
  test('candidates try USB first, then Wi-Fi, without duplicates', () {
    expect(
      AppConfig.resolveCandidates(
        primary: 'http://127.0.0.1:8000',
        wifiUrl: ' http://10.3.8.19:8000 ',
      ),
      ['http://127.0.0.1:8000', 'http://10.3.8.19:8000'],
    );
    expect(
      AppConfig.resolveCandidates(
        primary: 'http://127.0.0.1:8000',
        wifiUrl: '',
      ),
      ['http://127.0.0.1:8000'],
    );
  });

  group('AppConfig.resolveBaseUrl', () {
    test('Android uses an explicit API URL when provided', () {
      expect(
        AppConfig.resolveBaseUrl(
          isAndroid: true,
          compileTimeUrl: ' http://10.3.8.19:8000 ',
          dotenvUrl: 'http://192.168.1.10:8000',
        ),
        'http://10.3.8.19:8000',
      );
    });

    test('Android defaults to the adb reverse USB tunnel', () {
      expect(
        AppConfig.resolveBaseUrl(
          isAndroid: true,
          compileTimeUrl: '',
          dotenvUrl: 'http://192.168.1.10:8000',
        ),
        'http://127.0.0.1:8000',
      );
    });

    test('non-Android targets honor the compile-time URL first', () {
      expect(
        AppConfig.resolveBaseUrl(
          isAndroid: false,
          compileTimeUrl: ' https://api.example.test ',
          dotenvUrl: 'http://127.0.0.1:8000',
        ),
        'https://api.example.test',
      );
    });

    test('non-Android targets fall back to dotenv then localhost', () {
      expect(
        AppConfig.resolveBaseUrl(
          isAndroid: false,
          compileTimeUrl: '',
          dotenvUrl: ' http://192.168.1.10:8000 ',
        ),
        'http://192.168.1.10:8000',
      );
      expect(
        AppConfig.resolveBaseUrl(
          isAndroid: false,
          compileTimeUrl: '',
          dotenvUrl: '',
        ),
        'http://127.0.0.1:8000',
      );
    });
  });
}
