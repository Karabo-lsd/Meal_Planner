import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/text_input.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) return;

    // Basic client-side validation before hitting Supabase
    final emailRe = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}$');
    if (!emailRe.hasMatch(email)) {
      ref.read(authStateProvider.notifier).setError(
          'Please enter a valid email address (e.g. name@gmail.com).');
      return;
    }
    if (pass.length < 6) {
      ref.read(authStateProvider.notifier).setError(
          'Password must be at least 6 characters.');
      return;
    }

    ref.read(authStateProvider.notifier).register(
          email: email,
          password: pass,
          fullName: name,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Navigate to home when immediately signed in after registration
    if (authState.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -110,
              left: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0x66C2F0E3), Color(0x00C2F0E3)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0x66E8C8FF), Color(0x00E8C8FF)],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set up your profile and goals in minutes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF7D8799),
                        ),
                  ),
                  const SizedBox(height: 24),
                  GlassPanel(
                    padding: const EdgeInsets.all(18),
                    radius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextInput(controller: _nameController, label: 'Full name'),
                        const SizedBox(height: 14),
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
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              authState.error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        if (authState.error != null) const SizedBox(height: 12),
                        if (authState.successMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF7EE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: Color(0xFF2E7D32), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.successMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFF2E7D32)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (authState.successMessage != null)
                          const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Register',
                          loading: authState.isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text('Already have an account? Log in'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
