import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/camera/food_scanner_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/main_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/home/training_screen.dart';
import 'features/ingredients/pantry_screen.dart';
import 'features/profile/dietary_profile_screen.dart';
import 'features/profile/help_support_screen.dart';
import 'features/profile/manage_account_screen.dart';
import 'features/profile/onboarding_profile_sheet.dart';
import 'features/profile/user_profile_screen.dart';
import 'features/recipes/nutrition_screen.dart';
import 'features/recipes/recipe_detail_screen.dart';
import 'services/session_storage.dart';

bool _looksLikeJwt(String token) => token.split('.').length == 3;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeAppServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            title: 'Meal Planner',
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting Meal Planner...'),
                  ],
                ),
              ),
            ),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          return ProviderScope(
            child: _StartupErrorApp(
              message:
                  'The app could not start. Please check your connection and restart.',
            ),
          );
        }
        return const ProviderScope(child: MyApp());
      },
    );
  }
}

Future<void> _initializeAppServices() async {
  await Future.wait([
    dotenv.load(fileName: '.env', isOptional: true),
    Hive.initFlutter(),
  ]);
  await SessionStorage.init();

  var url = const String.fromEnvironment('SUPABASE_URL').trim();
  if (url.isEmpty) url = dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  var anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY').trim();
  if (anonKey.isEmpty) {
    anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';
  }
  if (url.isEmpty || !_looksLikeJwt(anonKey)) {
    throw StateError(
      'Set SUPABASE_URL and SUPABASE_ANON_KEY in the .env file.',
    );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    url = url
        .replaceFirst('127.0.0.1', '10.0.2.2')
        .replaceFirst('localhost', '10.0.2.2');
  }

  await Supabase.initialize(url: url, anonKey: anonKey);

  // Debug aid: --dart-define=SIGN_OUT_ON_START=true starts from the login screen.
  if (const bool.fromEnvironment('SIGN_OUT_ON_START')) {
    await Supabase.instance.client.auth.signOut();
  }
}

Map<String, WidgetBuilder> appRoutes() => {
  '/login': (_) => const LoginScreen(),
  '/reset-password': (_) => const ResetPasswordScreen(),
  '/register': (_) => const RegisterScreen(),
  '/home': (_) => const _ProfileGate(),
  '/foodScanner': (_) => const FoodScannerScreen(),
  '/recipeDetail': (_) => const RecipeDetailScreen(),
  '/pantry': (_) => const PantryScreen(),
  '/dietaryProfile': (_) => const DietaryProfileScreen(),
  '/profile': (_) => const UserProfileScreen(),
  '/manageAccount': (_) => const ManageAccountScreen(),
  '/savedRecipes': (_) => const NutritionScreen(showBackButton: true),
  '/helpSupport': (_) => const HelpSupportScreen(),
  '/analytics': (_) => const AnalyticsScreen(),
  '/notifications': (_) => const NotificationsScreen(),
};

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
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Meal Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => _EmailVerificationLinkGate(
        child: child ?? const SizedBox.shrink(),
        onContinue: () {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/home',
            (_) => false,
          );
        },
      ),

      routes: appRoutes(),

      home: const AuthGate(),
    );
  }
}

class _EmailVerificationLinkGate extends ConsumerStatefulWidget {
  const _EmailVerificationLinkGate({
    required this.child,
    required this.onContinue,
  });

  final Widget child;
  final VoidCallback onContinue;

  @override
  ConsumerState<_EmailVerificationLinkGate> createState() =>
      _EmailVerificationLinkGateState();
}

class _EmailVerificationLinkGateState
    extends ConsumerState<_EmailVerificationLinkGate> {
  String? _dismissedEmail;
  bool _recoveryNavigationQueued = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(supabaseAuthStreamProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery &&
          !_recoveryNavigationQueued) {
        _recoveryNavigationQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/reset-password', (_) => false);
        });
      }
    });
    final authState = ref.watch(supabaseAuthStreamProvider).valueOrNull;
    final user = authState?.session?.user;
    final pendingEmail = SessionStorage.isInitialized
        ? SessionStorage.loadPendingVerificationEmail()
        : null;
    final verifiedEmail = user?.email;
    final isVerificationReturn =
        pendingEmail != null &&
        verifiedEmail != null &&
        pendingEmail.toLowerCase() == verifiedEmail.toLowerCase() &&
        user?.emailConfirmedAt != null &&
        _dismissedEmail != pendingEmail;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (isVerificationReturn)
          _EmailVerifiedScreen(
            email: verifiedEmail,
            onContinue: () async {
              await SessionStorage.clearPendingVerificationEmail();
              if (!mounted) return;
              setState(() => _dismissedEmail = pendingEmail);
              widget.onContinue();
            },
          ),
      ],
    );
  }
}

class _EmailVerifiedScreen extends StatelessWidget {
  const _EmailVerifiedScreen({required this.email, required this.onContinue});

  final String email;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_rounded,
                      size: 46,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Email verified',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account is ready${email.isNotEmpty ? ' for $email' : ''}. Continue to set up your meal planner.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onContinue,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          Future.microtask(
            () => ref.read(authStateProvider.notifier).restoreSession(supaUser),
          );
          return const _ProfileGate();
        }

        return const LoginScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const LoginScreen(),
    );
  }
}

/// Signed-in users land on onboarding until their profile is complete,
/// then on the main app.
class _ProfileGate extends ConsumerWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onboardingCompleteProvider);

    return status.when(
      data: (complete) {
        if (complete) return const MainScreen();
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: OnboardingProfileSheet(
                  mandatory: true,
                  onSaved: () => ref.invalidate(onboardingCompleteProvider),
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We could not load your profile.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(onboardingCompleteProvider),
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () => ref.read(authStateProvider.notifier).logout(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
