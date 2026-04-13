import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/camera/food_scanner_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/main_screen.dart';
import 'features/ingredients/pantry_screen.dart';
import 'features/profile/dietary_profile_screen.dart';
import 'features/profile/user_profile_screen.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'services/session_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SessionStorage.init();
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://ivlktsefeogazukqwleo.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2bGt0c2VmZW9nYXp1a3F3bGVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxMzEzOTcsImV4cCI6MjA4ODcwNzM5N30.ECu2YvMQt5EwSLisTiaV-gfEAxFELglOMG7BQAsod14',
    ),
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Meal Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainScreen(),
        '/foodScanner': (_) => const FoodScannerScreen(),
        '/recipeDetail': (_) => const RecipeDetailScreen(),
        '/pantry': (_) => const PantryScreen(),
        '/dietaryProfile': (_) => const DietaryProfileScreen(),
        '/profile': (_) => const UserProfileScreen(),
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
