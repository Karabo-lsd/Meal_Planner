import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../features/profile/onboarding_profile_sheet.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/text_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authStateProvider.notifier).clearMessages());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (email.isEmpty || pass.isEmpty) return;

    // Basic client-side email format check before hitting Supabase
    final emailRe = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$');
    if (!emailRe.hasMatch(email)) {
      ref.read(authStateProvider.notifier).setError(
          'Please enter a valid email address (e.g. name@gmail.com).');
      return;
    }

    ref.read(authStateProvider.notifier).login(email, pass);
  }

  void _showOnboardingIfNeeded() {
    final profile = ref.read(dietaryProfileProvider);
    if (profile.isNotEmpty && ref.read(dietaryProfileProvider.notifier).hasCompletedOnboarding()) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return OnboardingProfileSheet(
          onSaved: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            Navigator.of(context).pushReplacementNamed('/home');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // if login completed, navigate to home
    final hasAuthenticatedUser = authState.user != null;

    if (hasAuthenticatedUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(dietaryProfileProvider.notifier).hasCompletedOnboarding()) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          _showOnboardingIfNeeded();
        }
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.22),
                      colorScheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.secondary.withValues(alpha: 0.18),
                      colorScheme.secondary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Smart Meal Planner',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue planning your meals.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.78),
                            ),
                          ),
                          const SizedBox(height: 28),
                          GlassPanel(
                            padding: const EdgeInsets.all(20),
                            radius: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextInput(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                TextInput(
                                  controller: _passwordController,
                                  label: 'Password',
                                  obscure: true,
                                ),
                                const SizedBox(height: 18),
                                if (authState.error != null)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      authState.error!,
                                      style: TextStyle(color: colorScheme.onErrorContainer),
                                    ),
                                  ),
                                if (authState.error != null) const SizedBox(height: 12),
                                PrimaryButton(
                                  label: 'Log In',
                                  loading: authState.isLoading,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                ref.read(authStateProvider.notifier).clearMessages();
                                Navigator.of(context).pushReplacementNamed('/register');
                              },
                              child: const Text("Don't have an account? Register"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
