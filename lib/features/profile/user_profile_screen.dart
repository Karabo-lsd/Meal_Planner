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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    try {
      await ref.read(authStateProvider.notifier).updateCurrentUserProfile({
        'name': submittedName,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile right now')),
      );
    }
  }

  Future<void> _showComingSoon(String title) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: const Text('This section is coming soon.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSettingsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Manage app preferences and account actions.'),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Log Out'),
                  subtitle: const Text('Sign out from this device'),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(sheetContext);
                    await ref.read(authStateProvider.notifier).logout();
                    if (!mounted) return;
                    navigator.pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final dietaryProfile = ref.watch(dietaryProfileProvider);
    final savedRecipesAsync = ref.watch(savedRecipesProvider);
    final user = authState.user;

    final displayName = (user?.displayName.trim().isNotEmpty == true)
        ? user!.displayName
        : 'User';
    final email = user?.email ?? 'No email available';
    final avatarUrl = user?.avatarUrl;

    final age = _toInt(dietaryProfile['age']);
    final height = _toDouble(dietaryProfile['height']);
    final weight = _toDouble(dietaryProfile['weight']);
    final goal = (dietaryProfile['goal'] as String?)?.trim();

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editDisplayName(displayName),
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
            ),
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ProfileHeroCard(
            displayName: displayName,
            email: email,
            avatarUrl: avatarUrl,
            goal: goal,
          ),
          const SizedBox(height: 16),
          _ProfileStatsGrid(
            weightLabel: _formatWeight(weight),
            ageLabel: _formatAge(age),
            heightLabel: _formatHeight(height),
            savedRecipesAsync: savedRecipesAsync,
          ),
          const SizedBox(height: 16),
          _ProfileSectionHeader(
            title: 'Account',
            subtitle: '',
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.person_outline_rounded,
            title: 'Manage Account',
            onTap: () => _editDisplayName(displayName),
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.restaurant_menu_rounded,
            title: 'Saved Recipes',
            onTap: () => Navigator.pushNamed(context, '/foodScanner'),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.track_changes_rounded,
            title: 'Goal Setting',
            onTap: () => Navigator.pushNamed(context, '/dietaryProfile'),
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => _showComingSoon('Help & Support'),
          ),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: _showSettingsSheet,
          ),
          const SizedBox(height: 18),
          _ProfileSectionHeader(
            title: 'Progress',
            subtitle: 'A premium snapshot of your nutrition journey.',
          ),
          const SizedBox(height: 12),
          _PremiumProgressCard(
            title: 'Favorite recipes',
            valueBuilder: (savedRecipesAsync.valueOrNull?.length ?? 0).toString(),
            subtitle: 'Saved ideas in your library',
            icon: Icons.bookmark_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _PremiumProgressCard(
            title: 'Current streak',
            valueBuilder: '12 days',
            subtitle: 'Keep the momentum going',
            icon: Icons.local_fire_department_rounded,
            color: colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.goal,
  });

  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? goal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final goalLabel = goal == null || goal!.isEmpty ? 'Set your primary goal' : _prettyGoal(goal!);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.96),
            colorScheme.secondary.withValues(alpha: 0.9),
            colorScheme.tertiary.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarHero(
                displayName: displayName,
                avatarUrl: avatarUrl,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProfileChip(label: goalLabel, icon: Icons.flag_rounded),
              _ProfileChip(label: 'Premium look', icon: Icons.workspace_premium_rounded),
              _ProfileChip(label: 'Smart tracking', icon: Icons.auto_awesome_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStatsGrid extends StatelessWidget {
  const _ProfileStatsGrid({
    required this.weightLabel,
    required this.ageLabel,
    required this.heightLabel,
    required this.savedRecipesAsync,
  });

  final String weightLabel;
  final String ageLabel;
  final String heightLabel;
  final AsyncValue<List<dynamic>> savedRecipesAsync;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final savedCount = savedRecipesAsync.valueOrNull?.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 2 ? 1.15 : 1.0,
          children: [
            _ProfileMetricCard(title: 'Weight', value: weightLabel, icon: Icons.monitor_weight_rounded, color: colorScheme.primary),
            _ProfileMetricCard(title: 'Age', value: ageLabel, icon: Icons.cake_rounded, color: colorScheme.tertiary),
            _ProfileMetricCard(title: 'Height', value: heightLabel, icon: Icons.height_rounded, color: colorScheme.secondary),
            _ProfileMetricCard(title: 'Saved', value: '$savedCount recipes', icon: Icons.bookmark_rounded, color: colorScheme.primaryContainer),
          ],
        );
      },
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _PremiumProgressCard extends StatelessWidget {
  const _PremiumProgressCard({
    required this.title,
    required this.valueBuilder,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String valueBuilder;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.78),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valueBuilder,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  const _ProfileSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.78),
              ),
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _prettyGoal(String goal) {
  final normalized = goal.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return goal;
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

class _AvatarHero extends StatelessWidget {
  const _AvatarHero({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);

    return Center(
      child: Container(
        width: 110,
        height: 110,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _AvatarFallback(initials: initials);
                  },
                )
              : _AvatarFallback(initials: initials),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
      ),
    );
  }
}

class _ProfileStatsCard extends StatelessWidget {
  const _ProfileStatsCard({
    required this.backgroundColor,
    required this.weightLabel,
    required this.ageLabel,
    required this.heightLabel,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  final Color backgroundColor;
  final String weightLabel;
  final String ageLabel;
  final String heightLabel;
  final Color primaryColor;
  final Color onSurfaceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              label: 'Weight',
              value: weightLabel,
              primaryColor: primaryColor,
              onSurfaceColor: onSurfaceColor,
            ),
          ),
          _StatSeparator(color: onSurfaceColor.withValues(alpha: 0.35)),
          Expanded(
            child: _StatColumn(
              label: 'Age',
              value: ageLabel,
              primaryColor: primaryColor,
              onSurfaceColor: onSurfaceColor,
            ),
          ),
          _StatSeparator(color: onSurfaceColor.withValues(alpha: 0.35)),
          Expanded(
            child: _StatColumn(
              label: 'Height',
              value: heightLabel,
              primaryColor: primaryColor,
              onSurfaceColor: onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  final String label;
  final String value;
  final Color primaryColor;
  final Color onSurfaceColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: onSurfaceColor.withValues(alpha: 0.65),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: onSurfaceColor,
              ),
        ),
      ],
    );
  }
}

class _StatSeparator extends StatelessWidget {
  const _StatSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Icon(
        Icons.keyboard_double_arrow_right_rounded,
        size: 20,
        color: color,
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: emphasize
          ? colorScheme.primaryContainer.withValues(alpha: 0.42)
          : colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: emphasize
                  ? colorScheme.primary.withValues(alpha: 0.34)
                  : colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: emphasize
                      ? colorScheme.primary.withValues(alpha: 0.18)
                      : colorScheme.primaryContainer.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: emphasize ? colorScheme.primary : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              Icon(
                Icons.keyboard_double_arrow_right_rounded,
                color: emphasize
                    ? colorScheme.primary.withValues(alpha: 0.88)
                    : colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
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

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

String _formatWeight(double? value) {
  if (value == null) return '--';
  if (value == value.roundToDouble()) return '${value.toInt()} kg';
  return '${value.toStringAsFixed(1)} kg';
}

String _formatAge(int? value) {
  if (value == null) return '--';
  return '$value Year';
}

String _formatHeight(double? value) {
  if (value == null) return '--';
  if (value == value.roundToDouble()) return '${value.toInt()} cm';
  return '${value.toStringAsFixed(1)} cm';
}
