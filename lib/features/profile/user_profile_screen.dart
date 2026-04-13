import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  Future<void> _editDisplayName(String currentName) async {
    final controller = TextEditingController(
      text: currentName == 'User' ? '' : currentName,
    );

    final submittedName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Display Name'),
          content: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'Enter your name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || submittedName == null) return;
    if (submittedName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    try {
      await ref.read(authStateProvider.notifier).updateCurrentUserProfile({
        'name': submittedName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile right now')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final dietaryProfile = ref.watch(dietaryProfileProvider);
    final user = authState.user;
    final displayName = (user?.displayName.trim().isNotEmpty == true)
        ? user!.displayName
        : 'User';
    final email = user?.email ?? 'No email available';
    final goals =
        (dietaryProfile['goals'] as Map<String, dynamic>?) ?? const {};
    final preferences =
        (dietaryProfile['preferences'] as Map<String, dynamic>?) ?? const {};
    final diet = (preferences['diet'] as String?) ?? 'balanced';

    final calories = _toInt(goals['daily_calories']);
    final proteinRatio = _toDouble(goals['protein_ratio']);
    final carbsRatio = _toDouble(goals['carb_ratio']);
    final fatRatio = _toDouble(goals['fat_ratio']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      displayName.characters.first.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Personal Details'),
                  subtitle: Text('User ID: ${user?.id ?? '-'}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Display Name'),
                  subtitle: Text(displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editDisplayName(displayName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Dietary Preferences'),
                  subtitle: const Text('Manage diet, goals, and restrictions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/dietaryProfile'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.kitchen_outlined),
                  title: const Text('Pantry'),
                  subtitle: const Text('Manage your ingredients and staples'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/pantry'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: const Text('Food Scanner'),
                  subtitle: const Text('Scan meals and log nutrition quickly'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/foodScanner'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrition Snapshot',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: 'Diet', value: _toTitleCase(diet)),
                      _InfoChip(
                        label: 'Calories',
                        value: calories != null ? '$calories kcal' : '-',
                      ),
                      _InfoChip(
                        label: 'Protein',
                        value: proteinRatio != null
                            ? '${proteinRatio.toStringAsFixed(0)}%'
                            : '-',
                      ),
                      _InfoChip(
                        label: 'Carbs',
                        value: carbsRatio != null
                            ? '${carbsRatio.toStringAsFixed(0)}%'
                            : '-',
                      ),
                      _InfoChip(
                        label: 'Fat',
                        value: fatRatio != null
                            ? '${fatRatio.toStringAsFixed(0)}%'
                            : '-',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  subtitle: const Text('Sign out from this device'),
                  onTap: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

String _toTitleCase(String value) {
  if (value.isEmpty) return value;
  final words = value.replaceAll('_', ' ').split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
