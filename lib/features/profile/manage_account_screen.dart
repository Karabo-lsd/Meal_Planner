import 'package:flutter/material.dart';
import '../../core/friendly_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class ManageAccountScreen extends ConsumerStatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  ConsumerState<ManageAccountScreen> createState() =>
      _ManageAccountScreenState();
}

class _ManageAccountScreenState extends ConsumerState<ManageAccountScreen> {
  bool _deletingAccount = false;

  Future<String?> _requestValue({
    required String title,
    required String label,
    required String initialValue,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _editDisplayName(String currentName) async {
    final name = await _requestValue(
      title: 'Edit display name',
      label: 'Display name',
      initialValue: currentName == 'User' ? '' : currentName,
    );
    if (!mounted || name == null) return;

    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (name.isEmpty || parts.isEmpty) {
      _showMessage('Enter a name before saving.');
      return;
    }

    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');
    try {
      await ref.read(authStateProvider.notifier).updateCurrentUserProfile({
        'first_name': firstName,
        'last_name': lastName,
      });
      if (mounted) _showMessage('Display name updated.');
    } catch (error) {
      if (mounted) _showMessage(friendlyErrorMessage(error, action: 'update your name'));
    }
  }

  Future<void> _changeEmail(String currentEmail) async {
    final email = await _requestValue(
      title: 'Change email address',
      label: 'New email address',
      initialValue: currentEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (!mounted || email == null) return;

    final validEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!validEmail.hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (email.toLowerCase() == currentEmail.toLowerCase()) {
      _showMessage('That is already your current email address.');
      return;
    }

    try {
      await ref.read(authServiceProvider).updateEmail(email);
      if (mounted) {
        _showMessage(
          'Check your email to confirm the address change. Your account will '
          'keep using the current address until confirmation.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(friendlyErrorMessage(error, action: 'request the email change'));
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    if (email.isEmpty) {
      _showMessage('There is no email address on this account.');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        _showMessage('Password reset instructions were sent to $email.');
      }
    } catch (error) {
      if (mounted) _showMessage(friendlyErrorMessage(error, action: 'send the password reset email'));
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      if (mounted) _showMessage(friendlyErrorMessage(error, action: 'sign out'));
    }
  }

  Future<void> _deleteAccount() async {
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account, profile, dietary '
              'preferences, saved recipes, meal plans, and food logs. This '
              'cannot be undone. Type DELETE to confirm.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmationController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Type DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              confirmationController.text.trim() == 'DELETE',
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    confirmationController.dispose();
    if (!mounted || confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await ref.read(authStateProvider.notifier).deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      if (mounted) _showMessage(friendlyErrorMessage(error, action: 'delete your account'));
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final colorScheme = Theme.of(context).colorScheme;
    final name = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : 'User';
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.person_outline_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email.isEmpty ? 'No email address available' : email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Account details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Display name'),
                  subtitle: Text(name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editDisplayName(name),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email address'),
                  subtitle: Text(email.isEmpty ? 'Not available' : email),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _changeEmail(email),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Reset password'),
                  subtitle: const Text('Send a secure reset link by email'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _sendPasswordReset(email),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Security', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: colorScheme.error),
              title: const Text('Log out'),
              subtitle: const Text('Sign out from this device'),
              onTap: _signOut,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: colorScheme.error,
              ),
              title: Text(
                _deletingAccount ? 'Deleting account...' : 'Delete account',
                style: TextStyle(color: colorScheme.error),
              ),
              subtitle: const Text(
                'Permanently remove your account and personal data',
              ),
              trailing: _deletingAccount
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _deletingAccount ? null : _deleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}
