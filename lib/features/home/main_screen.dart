import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../services/session_storage.dart';
import '../assistant/assistant_sheet.dart';
import '../camera/food_scanner_screen.dart';
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
  static const int _homeTabIndex = 0;
  static const int _scannerTabIndex = 2;
  static const double _assistantSize = 56;
  // Home, Recipes and Planner only.
  static const Set<int> _assistantTabs = {0, 1, 3};
  Offset? _assistantOffset;
  int _currentIndex = _homeTabIndex;
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
        if (saved == _scannerTabIndex) {
          SessionStorage.saveTab(userId, _homeTabIndex);
        } else {
          _currentIndex = saved;
        }
      }
    }
    _loadedPages[_currentIndex] = _buildPage(_currentIndex);
    // Warm up providers once user lands here so home recommendations render fast.
    Future.microtask(() {
      ref.read(pantryProvider);
      ref.read(dietaryProfileProvider);
      ref.read(savedRecipeIdsProvider);
      ref.read(recommendationsProvider.future).ignore();
      ref.read(nutritionSummaryProvider.future).ignore();
      ref.read(goalProgressProvider.future).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final padding = MediaQuery.of(context).padding;
          final minX = 8.0;
          final maxX = size.width - _assistantSize - 8;
          final minY = padding.top + 8;
          final maxY = size.height - _assistantSize - 110;
          final offset = _assistantOffset ?? Offset(maxX, maxY - 8);
          final clamped = Offset(
            offset.dx.clamp(minX, maxX > minX ? maxX : minX),
            offset.dy.clamp(minY, maxY > minY ? maxY : minY),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _currentIndex,
                  children: List<Widget>.generate(
                    _tabCount,
                    (index) => _loadedPages[index] ?? const SizedBox.shrink(),
                  ),
                ),
              ),
              if (_assistantTabs.contains(_currentIndex))
                Positioned(
                  left: clamped.dx,
                  top: clamped.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final current = _assistantOffset ?? clamped;
                        _assistantOffset = Offset(
                          (current.dx + details.delta.dx).clamp(
                            minX,
                            maxX > minX ? maxX : minX,
                          ),
                          (current.dy + details.delta.dy).clamp(
                            minY,
                            maxY > minY ? maxY : minY,
                          ),
                        );
                      });
                    },
                    child: Tooltip(
                      message: 'AI Assistant (drag to move)',
                      child: Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        elevation: 6,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _openAssistantSheet,
                          child: SizedBox(
                            width: _assistantSize,
                            height: _assistantSize,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
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
                          colors: [colorScheme.primary, colorScheme.tertiary],
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
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.white,
                      ),
                    ),
                    selectedIcon: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
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
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.white,
                      ),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AssistantSheet(onPlanWeek: () => _switchToTab(3)),
    );
  }

  void _switchToTab(int index) {
    setState(() {
      if (_currentIndex == _scannerTabIndex && index != _scannerTabIndex) {
        _loadedPages[_scannerTabIndex] = null;
      }
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
        return const NutritionScreen();
      case 2:
        return FoodScannerScreen(onBack: () => _switchToTab(_homeTabIndex));
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
