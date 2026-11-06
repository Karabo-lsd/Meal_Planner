import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/friendly_error.dart';
import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../core/recipe_filters.dart';
import '../../shared/widgets/recipe_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const List<String> _quickFilters = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'High Protein',
    'Vegan',
    'Keto',
    'Quick Meals',
    'Healthy',
    'Low Carb',
  ];

  static const List<_HomeCategory> _categories = [
    _HomeCategory(label: 'Healthy', emoji: '🥗', color: Color(0xFF668574)),
    _HomeCategory(label: 'Protein', emoji: '🥩', color: Color(0xFF806F5E)),
    _HomeCategory(label: 'Comfort Food', emoji: '🍕', color: Color(0xFF9A7966)),
    _HomeCategory(label: 'Drinks', emoji: '🥤', color: Color(0xFF71868D)),
    _HomeCategory(label: 'Pasta', emoji: '🍝', color: Color(0xFF9A8967)),
    _HomeCategory(label: 'Breakfast', emoji: '🥞', color: Color(0xFF8B8967)),
    _HomeCategory(label: 'Desserts', emoji: '🍰', color: Color(0xFF98777A)),
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _remoteQuery = '';
  Timer? _searchDebounce;
  String _selectedQuickFilter = 'All';
  String _selectedCategory = 'All';
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      ref.read(recipeFeedProvider.notifier).reset();
      ref.read(recipePageProvider.notifier).state = 0;
      ref.invalidate(recommendationsProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(nutritionSummaryProvider);
      await Future.wait([
        ref.read(recommendationsProvider.future),
        ref.read(goalProgressProvider.future),
        ref.read(nutritionSummaryProvider.future),
      ]);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                friendlyErrorMessage(error, action: 'refresh recipes'),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 0 || page > maxRecipePage) return;
    ref.read(recipeFeedProvider.notifier).reset();
    ref.read(recipePageProvider.notifier).state = page;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// If a later page has nothing left, go back and tell the user.
  void _handleEmptyPage(AsyncValue<List<Recipe>>? next) {
    final recipes = next?.valueOrNull;
    final page = ref.read(recipePageProvider);
    if (recipes == null || recipes.isNotEmpty || page == 0) return;
    ref.read(recipePageProvider.notifier).state = page - 1;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No more recipes to show right now.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).user;
    final profile = ref.watch(dietaryProfileProvider);
    final recommendationsAsync = _remoteQuery.isEmpty
        ? ref.watch(recommendationsProvider)
        : ref.watch(recipeSearchProvider(_remoteQuery));
    final goalProgressAsync = ref.watch(goalProgressProvider);
    final summaryAsync = ref.watch(nutritionSummaryProvider);
    final savedRecipeIds = ref.watch(savedRecipeIdsProvider);
    final feedState = ref.watch(recipeFeedProvider);

    ref.listen<AsyncValue<List<Recipe>>>(recommendationsProvider, (
      previous,
      next,
    ) {
      final recipes = next.valueOrNull;
      if (recipes != null) {
        ref.read(recipeFeedProvider.notifier).seedInitial(recipes);
      }
      if (_remoteQuery.isEmpty) _handleEmptyPage(next);
    });
    if (_remoteQuery.isNotEmpty) {
      ref.listen<AsyncValue<List<Recipe>>>(
        recipeSearchProvider(_remoteQuery),
        (_, next) => _handleEmptyPage(next),
      );
    }

    final goalProgress =
        goalProgressAsync.valueOrNull ?? const <String, dynamic>{};
    final summary = summaryAsync.valueOrNull ?? const <String, dynamic>{};
    final consumed = _mapFrom(goalProgress['consumed']);
    final targets = _mapFrom(goalProgress['targets']);

    final targetCalories = _doubleFrom(
      profile['daily_calorie_target'] ??
          targets['daily_calorie_target'] ??
          targets['daily_calories'],
    );
    final targetProtein = _doubleFrom(
      profile['daily_protein_target'] ?? targets['daily_protein_target'],
    );
    final consumedCalories = _doubleFrom(
      consumed['total_calories'] ?? summary['total_calories'],
    );
    final consumedProtein = _doubleFrom(
      consumed['total_protein'] ?? summary['total_protein'],
    );
    final remainingCalories = (targetCalories - consumedCalories)
        .clamp(0.0, targetCalories)
        .toDouble();
    final remainingProtein = (targetProtein - consumedProtein)
        .clamp(0.0, targetProtein)
        .toDouble();
    final firstName = user?.name?.trim().isNotEmpty == true
        ? user!.name!.trim()
        : (profile['first_name']?.toString().trim() ?? '');
    final displayName = firstName.isEmpty ? 'there' : firstName;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';
    final dietLabel = _dietLabel(profile['diet_type']);
    final weeklyGoalProgress = targetCalories <= 0
        ? 0.0
        : (consumedCalories / targetCalories).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _HomeBackdrop(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderRow(
                          userName: displayName,
                          onProfileTap: () =>
                              Navigator.pushNamed(context, '/profile'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$greeting, $displayName 👋',
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(height: 1.05),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your AI meal planner is tracking the day and suggesting the next best meal.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        _MetricGrid(
                          caloriesLabel: _formatRemainingCalories(
                            remainingCalories,
                          ),
                          caloriesProgress: weeklyGoalProgress,
                          proteinLabel: _formatRemainingProtein(
                            remainingProtein,
                          ),
                          proteinProgress: targetProtein <= 0
                              ? 0.0
                              : (consumedProtein / targetProtein).clamp(
                                  0.0,
                                  1.0,
                                ),
                          dietLabel: dietLabel,
                          goalLabel:
                              '${targetCalories.round().toString()} kcal',
                          goalProgress: weeklyGoalProgress,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: const _TodayLogCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 700),
                        () => _submitSearch(value),
                      );
                    },
                    onSubmitted: _submitSearch,
                    onClear: _resetSearch,
                    onVoiceTap: _showVoiceSearchHint,
                    onFilterTap: _showFilterSheet,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final label = _quickFilters[index];
                        final selected = _selectedQuickFilter == label;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedQuickFilter = selected ? 'All' : label;
                            });
                          },
                          showCheckmark: false,
                          selectedColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.72),
                          backgroundColor: colorScheme.surface,
                          side: BorderSide(
                            color: selected
                                ? colorScheme.primary.withValues(alpha: 0.35)
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.72,
                                  ),
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _SectionTitle(
                    title: 'Browse by mood',
                    subtitle: 'Quick picks for common meal intents.',
                    actionLabel: 'Reset',
                    onAction: _hasActiveFilters ? _resetFilters : null,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 128,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final selected = _selectedCategory == category.label;
                      return _CategoryBubble(
                        category: category,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            _selectedCategory = selected
                                ? 'All'
                                : category.label;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _SectionTitle(
                    title: 'Smart Meal Picks',
                    subtitle:
                        'A premium, AI-led recipe surface with clear nutrition context.',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                sliver: recommendationsAsync.when(
                  data: (initialRecipes) {
                    final recipes =
                        feedState.items.isNotEmpty && _remoteQuery.isEmpty
                        ? feedState.items
                        : initialRecipes;
                    final filteredRecipes = _applyFilters(recipes);
                    return SliverMainAxisGroup(
                      slivers: [
                        if (recipes.isEmpty)
                          SliverToBoxAdapter(
                            child: _EmptyState(
                              title: 'No recipes available right now',
                              subtitle:
                                  'No recipes matched your current dietary preferences. Review your allergies or foods to avoid in your profile, or refresh.',
                              icon: Icons.restaurant_outlined,
                              actionLabel: 'Refresh',
                              onAction: _refresh,
                              isActionLoading: _isRefreshing,
                            ),
                          )
                        else if (filteredRecipes.isEmpty)
                          SliverToBoxAdapter(
                            child: _EmptyState(
                              title: 'No recipes match this filter',
                              subtitle:
                                  'Try a broader search or reset the chips to bring the feed back.',
                              icon: Icons.restaurant_outlined,
                              actionLabel: 'Reset filters',
                              onAction: _resetFilters,
                            ),
                          )
                        else ...[
                          SliverLayoutBuilder(
                            builder: (context, constraints) {
                              return SliverGrid(
                                gridDelegate: recipeGridDelegate(
                                  recipeGridColumns(constraints.crossAxisExtent),
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final recipe = filteredRecipes[index];
                                    return RecipeCard(
                                      recipe: recipe,
                                      isFavorite: savedRecipeIds.contains(
                                        recipe.id,
                                      ),
                                      onTap: () => _openDetail(recipe),
                                      onFavoriteTap: () =>
                                          _toggleFavorite(recipe),
                                    );
                                  },
                                  childCount: filteredRecipes.length,
                                ),
                              );
                            },
                          ),
                          SliverToBoxAdapter(
                            child: _RecipePager(
                              page: ref.watch(recipePageProvider),
                              canGoNext:
                                  ref.watch(recipePageProvider) < maxRecipePage,
                              onPrevious: () => _goToPage(
                                ref.read(recipePageProvider) - 1,
                              ),
                              onNext: () => _goToPage(
                                ref.read(recipePageProvider) + 1,
                              ),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      ],
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        _LoadingRecipeGrid(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
                        ),
                      ],
                    ),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: _EmptyState(
                      title: 'Unable to load recommendations',
                      subtitle: _recommendationErrorMessage(error),
                      icon: Icons.cloud_off_rounded,
                      actionLabel: 'Retry',
                      onAction: _refresh,
                      isActionLoading: _isRefreshing,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recommendationErrorMessage(Object error) =>
      friendlyErrorMessage(error, action: 'load recipes');

  List<Recipe> _applyFilters(List<Recipe> recipes) {
    final matches = RecipeFilters.apply(
      recipes,
      quickFilter: _selectedQuickFilter,
      category: _selectedCategory,
    );
    if (_searchQuery.isEmpty ||
        (_remoteQuery.isNotEmpty &&
            _remoteQuery.toLowerCase() == _searchQuery)) {
      return matches;
    }

    final query = _normalize(_searchQuery);
    return matches.where((recipe) {
      final searchable = _normalize(
        [
          recipe.title,
          recipe.description ?? '',
          recipe.cuisine ?? '',
          ...?recipe.ingredients,
          ...?recipe.tags,
          ...?recipe.supportedDiets,
        ].join(' '),
      );
      return searchable.contains(query);
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedQuickFilter != 'All' ||
      _selectedCategory != 'All';

  Future<void> _toggleFavorite(Recipe recipe) async {
    try {
      await ref.read(savedRecipeIdsProvider.notifier).toggle(recipe.id);
      ref.invalidate(savedRecipesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error, action: 'update saved recipe'))),
      );
    }
  }

  void _openDetail(Recipe recipe) {
    Navigator.pushNamed(context, '/recipeDetail', arguments: recipe);
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    ref.read(recipePageProvider.notifier).state = 0;
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _remoteQuery = '';
    });
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    if (!mounted) return;
    ref.read(recipePageProvider.notifier).state = 0;
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      _remoteQuery = value.trim();
    });
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    ref.read(recipePageProvider.notifier).state = 0;
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _remoteQuery = '';
      _selectedQuickFilter = 'All';
      _selectedCategory = 'All';
    });
  }

  void _showVoiceSearchHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice search is coming soon.')),
    );
  }

  void _showFilterSheet() {
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
        var quickFilter = _selectedQuickFilter;
        var categoryFilter = _selectedCategory;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Filters use recipe labels and nutrition when available: '
                    'high protein is at least 25 g, low carb is at most 20 g, '
                    'and quick meals take 25 minutes or less.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quickFilters
                        .map(
                          (filter) => FilterChip(
                            label: Text(filter),
                            selected: quickFilter == filter,
                            onSelected: (_) {
                              setSheetState(() {
                                quickFilter = quickFilter == filter
                                    ? 'All'
                                    : filter;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _categories
                        .map(
                          (category) => FilterChip(
                            label: Text(category.label),
                            selected: categoryFilter == category.label,
                            onSelected: (_) {
                              setSheetState(() {
                                categoryFilter =
                                    categoryFilter == category.label
                                    ? 'All'
                                    : category.label;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _resetFilters();
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset all'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedQuickFilter = quickFilter;
                            _selectedCategory = categoryFilter;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ').trim();

  String _dietLabel(Object? diet) {
    final raw = diet?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Not set';
    return raw
        .split(RegExp(r'[_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Map<String, dynamic> _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  double _doubleFrom(Object? value) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed ?? 0;
  }

  String _formatRemainingCalories(double remainingCalories) {
    final rounded = remainingCalories.round();
    return '$rounded kcal remaining';
  }

  String _formatRemainingProtein(double remainingProtein) {
    final rounded = remainingProtein.round();
    return '$rounded g protein left';
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  colorScheme.primaryContainer.withValues(alpha: 0.28),
                  colorScheme.tertiaryContainer.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
        _BackdropOrb(
          top: -120,
          left: -80,
          size: 260,
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
        _BackdropOrb(
          top: 200,
          right: -60,
          size: 220,
          color: colorScheme.tertiary.withValues(alpha: 0.14),
        ),
        _BackdropOrb(
          bottom: -100,
          left: 24,
          size: 280,
          color: colorScheme.secondary.withValues(alpha: 0.14),
        ),
        child,
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.userName, required this.onProfileTap});

  final String userName;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userName.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.caloriesLabel,
    required this.caloriesProgress,
    required this.proteinLabel,
    required this.proteinProgress,
    required this.dietLabel,
    required this.goalLabel,
    required this.goalProgress,
  });

  final String caloriesLabel;
  final double caloriesProgress;
  final String proteinLabel;
  final double proteinProgress;
  final String dietLabel;
  final String goalLabel;
  final double goalProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 2 ? 0.98 : 0.9,
          children: [
            _MetricCard(
              title: 'Calories Remaining',
              value: caloriesLabel,
              progress: caloriesProgress,
              icon: Icons.local_fire_department_rounded,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            _MetricCard(
              title: 'Protein Remaining',
              value: proteinLabel,
              progress: proteinProgress,
              icon: Icons.fitness_center_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            _MetricCard(
              title: 'Eating Style',
              value: dietLabel,
              progress: null,
              icon: Icons.restaurant_menu_rounded,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            _MetricCard(
              title: 'Daily Goal',
              value: goalLabel,
              progress: goalProgress,
              icon: Icons.flag_circle_rounded,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.progress,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final double? progress;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (progress != null)
                Text(
                  '${(progress! * 100).clamp(0, 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress!.clamp(0.0, 1.0),
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onVoiceTap,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onVoiceTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search recipes, ingredients or ask AI...',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIconConstraints: const BoxConstraints(minWidth: 112),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Voice search',
                onPressed: onVoiceTap,
                icon: const Icon(Icons.mic_none_rounded),
              ),
              IconButton(
                tooltip: 'Filter',
                onPressed: onFilterTap,
                icon: const Icon(Icons.tune_rounded),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _HomeCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: selected ? 1.03 : 1.0,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? category.color.withValues(alpha: 0.34)
                  : Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? category.color.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      category.color.withValues(alpha: 0.72),
                      category.color.withValues(alpha: 0.52),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Text(
                    category.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.isActionLoading = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isActionLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            ),
            child: Icon(icon, size: 32, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: isActionLoading ? null : onAction,
            child: isActionLoading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Refreshing...'),
                    ],
                  )
                : Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _RecipePager extends StatelessWidget {
  const _RecipePager({
    required this.page,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: page > 0 ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Page ${page + 1}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          OutlinedButton.icon(
            onPressed: canGoNext ? onNext : null,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _LoadingRecipeGrid extends StatelessWidget {
  const _LoadingRecipeGrid({required this.crossAxisCount});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: crossAxisCount * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: crossAxisCount >= 4
                ? 0.74
                : crossAxisCount == 3
                ? 0.68
                : 0.62,
          ),
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeCategory {
  const _HomeCategory({
    required this.label,
    required this.emoji,
    required this.color,
  });

  final String label;
  final String emoji;
  final Color color;
}

class _TodayLogCard extends ConsumerWidget {
  const _TodayLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final logs = ref.watch(todayLogsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's meals",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your food log for today',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          logs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => Text(
              'Could not load your meal log.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.48,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Nothing logged yet. Log a meal to see it here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final (index, item) in items.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.58,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              (item['meal_slot']?.toString() ?? 'Meal')
                                  .replaceAll('_', ' '),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (item['recipes'] as Map?)?['title']
                                          ?.toString() ??
                                      (item['foods_master']
                                              as Map?)?['canonical_name']
                                          ?.toString() ??
                                      item['food_name']?.toString() ??
                                      'Meal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${((item['calories'] as num?) ?? 0).round()} kcal',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(mealServiceProvider)
                                  .deleteLog(item['id'].toString());
                              ref.invalidate(todayLogsProvider);
                              ref.invalidate(goalProgressProvider);
                              ref.invalidate(nutritionSummaryProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
