import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/camera/food_scanner_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/main_screen.dart';
import 'features/home/training_screen.dart';
import 'features/ingredients/pantry_screen.dart';
import 'features/profile/dietary_profile_screen.dart';
import 'features/profile/user_profile_screen.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'services/session_storage.dart';

String _defaultLocalSupabaseUrlForPlatform() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // Android emulators access host localhost via 10.0.2.2.
    return 'http://10.0.2.2:54321';
  }
  return 'http://127.0.0.1:54321';
}

bool _isLocalLoopbackHost(String host) {
  switch (host) {
    case '127.0.0.1':
    case 'localhost':
    case '10.0.2.2':
      return true;
    default:
      return false;
  }
}

String _sanitizeDefineValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.contains(r'${env:')) return '';
  if (trimmed.toLowerCase() == 'null') return '';
  return trimmed;
}

bool _looksLikeJwt(String token) => token.split('.').length == 3;

bool _isLocalSupabaseUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return _isLocalLoopbackHost(uri.host);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _initializeAppServices();

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  } catch (e) {
    runApp(
      ProviderScope(
        child: _StartupErrorApp(
          message: e.toString(),
        ),
      ),
    );
  }
}

Future<void> _initializeAppServices() async {
  const defaultCloudSupabaseUrl = 'https://ivlktsefeogazukqwleo.supabase.co';
  const defaultCloudSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2bGt0c2VmZW9nYXp1a3F3bGVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxMzEzOTcsImV4cCI6MjA4ODcwNzM5N30.ECu2YvMQt5EwSLisTiaV-gfEAxFELglOMG7BQAsod14';

  await Hive.initFlutter();
  await SessionStorage.init();
  const configuredSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultCloudSupabaseUrl,
  );
  const configuredSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: defaultCloudSupabaseAnonKey,
  );

    var runtimeSupabaseUrl = _sanitizeDefineValue(configuredSupabaseUrl).isNotEmpty
      ? _sanitizeDefineValue(configuredSupabaseUrl)
      : defaultCloudSupabaseUrl;

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      runtimeSupabaseUrl.contains('127.0.0.1')) {
    runtimeSupabaseUrl = runtimeSupabaseUrl.replaceFirst('127.0.0.1', '10.0.2.2');
  }

  if (runtimeSupabaseUrl.startsWith('https://localhost') ||
      runtimeSupabaseUrl.startsWith('https://127.0.0.1') ||
      runtimeSupabaseUrl.startsWith('https://10.0.2.2')) {
    runtimeSupabaseUrl = runtimeSupabaseUrl.replaceFirst('https://', 'http://');
  }

  final parsedUrl = Uri.tryParse(runtimeSupabaseUrl);
  final isMalformedUrl = parsedUrl == null ||
      !parsedUrl.hasScheme ||
      parsedUrl.host.isEmpty ||
      !(parsedUrl.scheme == 'https' || parsedUrl.scheme == 'http');

  if (isMalformedUrl) {
    runtimeSupabaseUrl = defaultCloudSupabaseUrl;
  }

  var runtimeSupabaseAnonKey = _sanitizeDefineValue(configuredSupabaseAnonKey).isNotEmpty
      ? _sanitizeDefineValue(configuredSupabaseAnonKey)
      : defaultCloudSupabaseAnonKey;

  if (!_looksLikeJwt(runtimeSupabaseAnonKey)) {
    if (_isLocalSupabaseUrl(runtimeSupabaseUrl)) {
      // If local key is missing/invalid, fall back to known-good cloud pair.
      runtimeSupabaseUrl = defaultCloudSupabaseUrl;
    }
    runtimeSupabaseAnonKey = defaultCloudSupabaseAnonKey;
  }

  await Supabase.initialize(
  url: runtimeSupabaseUrl,
  anonKey: runtimeSupabaseAnonKey,
);
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Startup Configuration Error',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The app could not initialize. Check your SUPABASE_URL and SUPABASE_ANON_KEY values.',
                ),
                const SizedBox(height: 12),
                SelectableText(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  

  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainScreen(),
        '/foodScanner': (_) => const FoodScannerScreen(),
        '/recipeDetail': (_) => const RecipeDetailScreen(),
        '/pantry': (_) => const PantryScreen(),
        '/dietaryProfile': (_) => const DietaryProfileScreen(),
        '/profile': (_) => const UserProfileScreen(),
        '/analytics': (_) => const AnalyticsScreen(),
      },

      home: const AuthGate(),
    );
  }
}


/// Routes to [LoginScreen] when signed out and [MainScreen] when signed in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(supabaseAuthStreamProvider);

    return authState.when(
      data: (state) {
        if (state.session != null) {
          // Restore profile from cache (or fetch fresh) so the user's name
          // and preferences are available without a new explicit login.
          final supaUser = state.session!.user;
          Future.microtask(() =>
            ref.read(authStateProvider.notifier).restoreSession(supaUser));
          return const MainScreen();
        }

        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const LoginScreen(),
    );
  }
}
