import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/profile_onboarding.dart';
import '../../core/providers.dart';
import '../../services/session_storage.dart';
import '../camera/food_scanner_screen.dart';
import '../profile/onboarding_profile_sheet.dart';
import '../profile/user_profile_screen.dart';
import 'dashboard_screen_premium.dart';
import '../recipes/nutrition_screen.dart';
import 'training_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const int _tabCount = 5;
  int _currentIndex = 0;
  late final List<Widget?> _loadedPages;

  @override
  void initState() {
    super.initState();
    _loadedPages = List<Widget?>.filled(_tabCount, null);

    // Restore last active tab for this user.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final saved = SessionStorage.loadTab(userId);
      if (saved >= 0 && saved < _tabCount) {
        _currentIndex = saved;
      }
    }
    _loadedPages[_currentIndex] = _buildPage(_currentIndex);
    // Warm up providers once user lands here so home recommendations render fast.
    Future.microtask(() {
      ref.read(pantryProvider);
      ref.read(dietaryProfileProvider);
      ref.read(savedRecipeIdsProvider);
      ref.read(recommendationsProvider.future);
      ref.read(nutritionSummaryProvider.future);
      ref.read(goalProgressProvider.future);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showProfileSetupReminderIfNeeded();
    });
  }

  Future<void> _showProfileSetupReminderIfNeeded() async {
    if (!mounted) return;

    final profile = ref.read(dietaryProfileProvider);
    if (!shouldPromptForProfileSetup(profile)) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || SessionStorage.hasProfileSetupReminderBeenDismissed(userId)) return;

    final authUser = ref.read(authStateProvider).user;
    if (authUser == null) return;

    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    final latestProfile = ref.read(dietaryProfileProvider);
    if (!shouldPromptForProfileSetup(latestProfile)) return;

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
          },
          onDismissed: () async {
            await SessionStorage.markProfileSetupReminderDismissed(userId);
          },
          onEditLater: () async {
            await SessionStorage.markProfileSetupReminderDismissed(userId);
            if (!mounted) return;
            Navigator.of(context).pushNamed('/profile');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _tabCount,
          (index) => _loadedPages[index] ?? const SizedBox.shrink(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAssistantSheet,
        tooltip: 'AI Assistant',
        child: const Icon(Icons.auto_awesome_rounded),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Material(
            color: colorScheme.surface.withValues(alpha: 0.96),
            elevation: 0,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                backgroundColor: Colors.transparent,
                height: 74,
                onDestinationSelected: _switchToTab,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.restaurant_menu_rounded),
                    selectedIcon: Icon(Icons.restaurant_menu_rounded),
                    label: 'Recipes',
                  ),
                  NavigationDestination(
                    icon: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Colors.white),
                    ),
                    selectedIcon: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: Colors.white),
                    ),
                    label: 'Scan',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.calendar_month_rounded),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Planner',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAssistantSheet() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
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
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.tertiary,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Assistant',
                            style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Ask for recipes, meal plans, or swaps instantly.',
                            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AssistantActionChip(
                      icon: Icons.restaurant_rounded,
                      label: 'Suggest dinner',
                      onTap: () => _switchAndClose(sheetContext, 1),
                    ),
                    _AssistantActionChip(
                      icon: Icons.fitness_center_rounded,
                      label: 'High protein meals',
                      onTap: () => _switchAndClose(sheetContext, 1),
                    ),
                    _AssistantActionChip(
                      icon: Icons.calendar_month_rounded,
                      label: 'Plan my week',
                      onTap: () => _switchAndClose(sheetContext, 3),
                    ),
                    _AssistantActionChip(
                      icon: Icons.document_scanner_rounded,
                      label: 'Scan food',
                      onTap: () => _switchAndClose(sheetContext, 2),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'What can I cook with chicken?',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI chat is coming soon.')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _switchAndClose(BuildContext sheetContext, int index) {
    Navigator.pop(sheetContext);
    _switchToTab(index);
  }

  void _switchToTab(int index) {
    setState(() {
      _currentIndex = index;
      _loadedPages[index] ??= _buildPage(index);
    });
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      SessionStorage.saveTab(userId, index);
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return NutritionScreen(onBackToHome: () => _switchToTab(0));
      case 2:
        return const FoodScannerScreen();
      case 3:
        return const GroceryScreen();
      case 4:
      default:
        return const UserProfileScreen();
    }
  }
}

class _AssistantActionChip extends StatelessWidget {
  const _AssistantActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
      onPressed: onTap,
      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.88),
      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.46)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}