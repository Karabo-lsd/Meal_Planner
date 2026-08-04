import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';

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
    _HomeCategory(label: 'Healthy', emoji: '🥗', color: Color(0xFF4CAF80)),
    _HomeCategory(label: 'Protein', emoji: '🥩', color: Color(0xFF2F8F4E)),
    _HomeCategory(label: 'Comfort Food', emoji: '🍕', color: Color(0xFFFF8A3D)),
    _HomeCategory(label: 'Drinks', emoji: '🥤', color: Color(0xFF4B8CF6)),
    _HomeCategory(label: 'Pasta', emoji: '🍝', color: Color(0xFFF2B544)),
    _HomeCategory(label: 'Breakfast', emoji: '🥞', color: Color(0xFF77C587)),
    _HomeCategory(label: 'Desserts', emoji: '🍰', color: Color(0xFFE35D5D)),
  ];

  static const Set<String> _legacyFallbackIds = {'9901', '9902', '9903'};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedQuickFilter = 'All';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(recommendationsProvider);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(nutritionSummaryProvider);
    await Future.wait([
      ref.read(recommendationsProvider.future),
      ref.read(goalProgressProvider.future),
      ref.read(nutritionSummaryProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).user;
    final profile = ref.watch(dietaryProfileProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final goalProgressAsync = ref.watch(goalProgressProvider);
    final summaryAsync = ref.watch(nutritionSummaryProvider);
    final savedRecipeIds = ref.watch(savedRecipeIdsProvider);

    final goalProgress = goalProgressAsync.valueOrNull ?? const <String, dynamic>{};
    final summary = summaryAsync.valueOrNull ?? const <String, dynamic>{};
    final consumed = _mapFrom(goalProgress['consumed']);
    final targets = _mapFrom(goalProgress['targets']);

    final targetCalories = _doubleFrom(
      profile['daily_calorie_target'] ??
          targets['daily_calorie_target'] ??
          targets['daily_calories'] ??
          2200,
    );
    final targetProtein = _doubleFrom(
      profile['daily_protein_target'] ??
          targets['daily_protein_target'] ??
          120,
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
    final waterProgress = _doubleFrom(profile['water_progress'] ?? 0.75).clamp(0.0, 1.0);
    final weeklyGoalProgress = targetCalories <= 0
        ? 0.0
        : (consumedCalories / targetCalories).clamp(0.0, 1.0);

    final insight = _buildAiInsight(
      remainingCalories: remainingCalories,
      remainingProtein: remainingProtein,
      weeklyGoalProgress: weeklyGoalProgress,
      targetCalories: targetCalories,
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeBackdrop(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(
                        userName: user?.name?.trim().isNotEmpty == true
                          ? user!.name!.trim()
                          : 'Karabo',
                        onProfileTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Good Morning, ${user?.name?.trim().isNotEmpty == true ? user!.name!.trim() : 'Karabo'} 👋',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your AI meal planner is tracking the day and suggesting the next best meal.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _MetricGrid(
                        caloriesLabel: _formatRemainingCalories(remainingCalories),
                        caloriesProgress: weeklyGoalProgress,
                        proteinLabel: _formatRemainingProtein(remainingProtein),
                        proteinProgress: targetProtein <= 0 ? 0.0 : (consumedProtein / targetProtein).clamp(0.0, 1.0),
                        waterLabel: '6 / 8 cups',
                        waterProgress: waterProgress,
                        goalLabel: '${targetCalories.round().toString()} kcal',
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
                child: _AiRecommendationCard(
                  insight: insight,
                  recommendationsAsync: recommendationsAsync,
                  onGenerateNew: _refresh,
                  onAskAi: _openAssistantSheet,
                ),
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
                  },
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
                  subtitle: 'Colorful shortcuts for common meal intents.',
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
                          _selectedCategory = selected ? 'All' : category.label;
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
                  subtitle: 'A premium, AI-led recipe surface with clear nutrition context.',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              sliver: recommendationsAsync.when(
                data: (recipes) {
                  final showcaseRecipes = _withShowcaseRecipes(recipes);
                  final filteredRecipes = _applyFilters(showcaseRecipes);
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      if (_usesFallbackRecipes(recipes)) ...[
                        _FallbackBanner(
                          onRefresh: _refresh,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (filteredRecipes.isEmpty)
                        _EmptyState(
                          title: 'No recipes match this filter',
                          subtitle: 'Try a broader search or reset the chips to bring the feed back.',
                          icon: Icons.restaurant_outlined,
                          actionLabel: 'Reset filters',
                          onAction: _resetFilters,
                        )
                      else ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth >= 1000
                                ? 4
                                : constraints.maxWidth >= 700
                                    ? 3
                                    : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                              itemCount: filteredRecipes.length,
                              itemBuilder: (context, index) {
                                final recipe = filteredRecipes[index];
                                return _RecipeCard(
                                  recipe: recipe,
                                  badge: _recipeBadge(recipe, index),
                                  rating: _ratingForRecipe(recipe),
                                  isFavorite: savedRecipeIds.contains(recipe.id),
                                  onTap: () => _openDetail(recipe),
                                  onFavoriteTap: () => _toggleFavorite(recipe),
                                );
                              },
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                    ]),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _LoadingRecipeGrid(
                        crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
                      ),
                    ],
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: _EmptyState(
                    title: 'Unable to load recommendations',
                    subtitle: 'Check your connection or try again after the backend comes back online.',
                    icon: Icons.cloud_off_rounded,
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Recipe> _applyFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final title = recipe.title.toLowerCase();
      final description = (recipe.description ?? '').toLowerCase();
        final ingredients = (recipe.ingredients ?? const <String>[])
          .map((item) => item.toLowerCase())
          .toList();

      final queryOk = _searchQuery.isEmpty ||
          title.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          ingredients.any((item) => item.contains(_searchQuery)) ||
          _recipeTags(recipe).any((tag) => tag.contains(_searchQuery));

      final categoryOk = _selectedCategory == 'All' || _matchesCategory(recipe, _selectedCategory);
      final quickFilterOk = _selectedQuickFilter == 'All' || _matchesQuickFilter(recipe, _selectedQuickFilter);
      return queryOk && categoryOk && quickFilterOk;
    }).toList();
  }

  bool _matchesCategory(Recipe recipe, String category) {
    final normalizedTags = _recipeTags(recipe).map(_normalize).toSet();
    final normalizedTitle = _normalize(recipe.title);
    final normalizedDescription = _normalize(recipe.description ?? '');

    switch (category) {
      case 'Healthy':
        return normalizedTags.contains('healthy') || normalizedTitle.contains('healthy') || normalizedDescription.contains('healthy');
      case 'Protein':
        return normalizedTags.contains('high protein') || normalizedTags.contains('protein') || normalizedTitle.contains('protein');
      case 'Comfort Food':
        return normalizedTags.contains('comfort') || normalizedTitle.contains('pizza') || normalizedTitle.contains('burger');
      case 'Drinks':
        return normalizedTags.contains('drink') || normalizedTags.contains('smoothie') || normalizedTitle.contains('drink') || normalizedTitle.contains('smoothie');
      case 'Pasta':
        return normalizedTags.contains('pasta') || normalizedTitle.contains('pasta') || normalizedDescription.contains('pasta');
      case 'Breakfast':
        return normalizedTags.contains('breakfast') || normalizedTitle.contains('breakfast');
      case 'Desserts':
        return normalizedTags.contains('dessert') || normalizedTitle.contains('dessert') || normalizedTitle.contains('cake');
      default:
        return true;
    }
  }

  bool _matchesQuickFilter(Recipe recipe, String filter) {
    final tags = _recipeTags(recipe).map(_normalize).toSet();
    final title = _normalize(recipe.title);
    final description = _normalize(recipe.description ?? '');

    switch (filter) {
      case 'Breakfast':
        return tags.contains('breakfast') || title.contains('breakfast');
      case 'Lunch':
        return tags.contains('lunch') || title.contains('bowl') || title.contains('salad');
      case 'Dinner':
        return tags.contains('dinner') || title.contains('dinner') || title.contains('stir fry');
      case 'High Protein':
        return tags.contains('high protein') || tags.contains('protein') || (recipe.protein ?? 0) >= 25;
      case 'Vegan':
        return tags.contains('vegan') || tags.contains('plant based') || description.contains('vegan');
      case 'Keto':
        return tags.contains('keto') || tags.contains('low carb') || description.contains('keto');
      case 'Quick Meals':
        return (recipe.prepTime ?? 99) <= 25;
      case 'Healthy':
        return tags.contains('healthy') || tags.contains('balanced');
      case 'Low Carb':
        return tags.contains('low carb') || tags.contains('keto') || title.contains('low carb');
      default:
        return true;
    }
  }

  List<String> _recipeTags(Recipe recipe) {
    final tags = <String>{
      ...(recipe.tags ?? const <String>[]),
      ...(recipe.supportedDiets ?? const <String>[]),
    };
    return tags.map((entry) => entry.toLowerCase().replaceAll('_', ' ').trim()).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedQuickFilter != 'All' || _selectedCategory != 'All';

  bool _usesFallbackRecipes(List<Recipe> recipes) {
    if (recipes.isEmpty) return false;
    return recipes.every((recipe) {
      final id = recipe.id.trim().toLowerCase();
      return id.startsWith('mock-') || _legacyFallbackIds.contains(id);
    });
  }

  List<Recipe> _withShowcaseRecipes(List<Recipe> recipes) {
    final byId = <String, Recipe>{
      for (final recipe in recipes) recipe.id: recipe,
    };

    final previewRecipes = <Recipe>[
      Recipe(
        id: 'preview-home-1',
        title: 'Avocado Egg Toast Stack',
        description: 'Creamy avocado, eggs, and greens on toasted sourdough.',
        calories: 480,
        protein: 24,
        prepTime: 12,
        tags: ['Breakfast', 'High Protein'],
      ),
      Recipe(
        id: 'preview-home-2',
        title: 'Citrus Chicken Grain Bowl',
        description: 'Chicken, brown rice, and roasted veg with citrus dressing.',
        calories: 620,
        protein: 38,
        prepTime: 24,
        tags: ['Lunch', 'Healthy'],
      ),
    ];

    for (final preview in previewRecipes) {
      byId.putIfAbsent(preview.id, () => preview);
    }

    return byId.values.toList();
  }

  String _recipeBadge(Recipe recipe, int index) {
    final tags = _recipeTags(recipe).map(_normalize).toSet();
    if (tags.contains('high protein') || tags.contains('protein')) return 'High Protein';
    if (tags.contains('vegan')) return 'Vegan';
    if (tags.contains('vegetarian')) return 'Vegetarian';
    if (tags.contains('keto') || tags.contains('low carb')) return 'Low Carb';
    if (index == 0) return 'AI Pick';
    return 'Trending';
  }

  double _ratingForRecipe(Recipe recipe) {
    return 4.4 + ((recipe.id.hashCode.abs() % 6) / 10.0);
  }

  String _buildAiInsight({
    required double remainingCalories,
    required double remainingProtein,
    required double weeklyGoalProgress,
    required double targetCalories,
  }) {
    if (remainingProtein <= 25) {
      return 'You\'re low on protein today. The next meal should lean toward chicken, eggs, yogurt, or legumes.';
    }
    if (remainingCalories <= targetCalories * 0.25) {
      return 'You\'re close to your calorie goal. A lighter dinner will keep the day balanced.';
    }
    if (weeklyGoalProgress < 0.5) {
      return 'Your weekly goal is still open. Build momentum with a simple high-protein meal.';
    }
    return 'You\'re on a healthy pace. The best next meal is one that protects protein and keeps calories in range.';
  }

  void _toggleFavorite(Recipe recipe) {
    ref.read(savedRecipeIdsProvider.notifier).toggle(recipe.id);
  }

  void _openDetail(Recipe recipe) {
    Navigator.pushNamed(
      context,
      '/recipeDetail',
      arguments: recipe,
    );
  }

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search filters',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Refine by meal intent or clear everything with one tap.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
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
                          selected: _selectedQuickFilter == filter,
                          onSelected: (_) {
                            setState(() {
                              _selectedQuickFilter = filter;
                            });
                            Navigator.pop(sheetContext);
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
                          selected: _selectedCategory == category.label,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category.label;
                            });
                            Navigator.pop(sheetContext);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _resetFilters();
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset all filters'),
                ),
              ],
            ),
          ),
        );
      },
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
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
                            'Ask for recipes, weekly plans, or ingredient swaps.',
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
                      label: 'What can I cook with chicken?',
                      onTap: () => _assistantShortcut(sheetContext, 'What can I cook with chicken?'),
                    ),
                    _AssistantActionChip(
                      icon: Icons.fitness_center_rounded,
                      label: 'High protein meals under 600 calories',
                      onTap: () => _assistantShortcut(sheetContext, 'High protein meals under 600 calories'),
                    ),
                    _AssistantActionChip(
                      icon: Icons.calendar_month_rounded,
                      label: 'Generate my week',
                      onTap: () => _assistantShortcut(sheetContext, 'Generate my weekly meal plan'),
                    ),
                    _AssistantActionChip(
                      icon: Icons.document_scanner_rounded,
                      label: 'Scan ingredients',
                      onTap: () => _assistantShortcut(sheetContext, 'Scan ingredients'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'What should I eat today?',
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

  void _assistantShortcut(BuildContext sheetContext, String prompt) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$prompt - opening smart meal planning soon.')),
    );
  }

  String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ').trim();

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
                  colorScheme.background,
                  colorScheme.primaryContainer.withValues(alpha: 0.28),
                  colorScheme.tertiaryContainer.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ),
        _BackdropOrb(top: -120, left: -80, size: 260, color: colorScheme.primary.withValues(alpha: 0.18)),
        _BackdropOrb(top: 200, right: -60, size: 220, color: colorScheme.tertiary.withValues(alpha: 0.14)),
        _BackdropOrb(bottom: -100, left: 24, size: 280, color: colorScheme.secondary.withValues(alpha: 0.14)),
        child,
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({this.top, this.left, this.right, this.bottom, required this.size, required this.color});

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
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new notifications')),
          ),
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
    required this.waterLabel,
    required this.waterProgress,
    required this.goalLabel,
    required this.goalProgress,
  });

  final String caloriesLabel;
  final double caloriesProgress;
  final String proteinLabel;
  final double proteinProgress;
  final String waterLabel;
  final double waterProgress;
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
              title: 'Water Progress',
              value: waterLabel,
              progress: waterProgress,
              icon: Icons.water_drop_rounded,
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
  final double progress;
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
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
              Text(
                '${(progress * 100).clamp(0, 100).round()}%',
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard({
    required this.insight,
    required this.recommendationsAsync,
    required this.onGenerateNew,
    required this.onAskAi,
  });

  final String insight;
  final AsyncValue<List<Recipe>> recommendationsAsync;
  final Future<void> Function() onGenerateNew;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.95),
            colorScheme.secondary.withValues(alpha: 0.9),
            colorScheme.tertiary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -16,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -10,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: recommendationsAsync.when(
              loading: () => const _AiRecommendationLoading(),
              error: (_, __) => _AiRecommendationBody(
                insight: insight,
                items: const [],
                onGenerateNew: onGenerateNew,
                onAskAi: onAskAi,
              ),
              data: (recipes) => _AiRecommendationBody(
                insight: insight,
                items: recipes.take(3).toList(),
                onGenerateNew: onGenerateNew,
                onAskAi: onAskAi,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRecommendationBody extends StatelessWidget {
  const _AiRecommendationBody({
    required this.insight,
    required this.items,
    required this.onGenerateNew,
    required this.onAskAi,
  });

  final String insight;
  final List<Recipe> items;
  final Future<void> Function() onGenerateNew;
  final VoidCallback onAskAi;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
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
                    'AI Recommendation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'Smart, adaptive, and nutrition-aware.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          insight,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 14),
        Text(
          'Suggested meals',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(
            'Your recommendations will appear here once the feed loads.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (recipe) => _SuggestionPill(
                    label: recipe.title,
                    icon: Icons.restaurant_rounded,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () async => onGenerateNew(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colorScheme.primary,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Generate New'),
            ),
            OutlinedButton.icon(
              onPressed: onAskAi,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask AI'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiRecommendationLoading extends StatelessWidget {
  const _AiRecommendationLoading();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.16),
      highlightColor: Colors.white.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 22, width: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 14),
          Container(height: 16, width: 220, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              3,
              (index) => Container(
                height: 36,
                width: index == 2 ? 150 : 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(height: 44, width: 136, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(width: 12),
              Container(height: 44, width: 118, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onVoiceTap,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                  ? category.color.withValues(alpha: 0.55)
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: selected ? category.color.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
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
                      category.color.withValues(alpha: 0.95),
                      category.color.withValues(alpha: 0.72),
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

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.badge,
    required this.rating,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Recipe recipe;
  final String badge;
  final double rating;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    child: _ImagePlaceholder(color: colorScheme.surfaceContainerHighest),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _MiniBadge(label: badge),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IconButton.filled(
                      onPressed: onFavoriteTap,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.46),
                      ),
                      icon: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.redAccent : Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _MiniBadge(
                      label: '${rating.toStringAsFixed(1)} ★',
                      backgroundColor: Colors.black.withValues(alpha: 0.56),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetricPill(
                          icon: Icons.local_fire_department_rounded,
                          label: '${recipe.calories ?? 0} kcal',
                          color: colorScheme.tertiary,
                        ),
                        _MetricPill(
                          icon: Icons.fitness_center_rounded,
                          label: '${(recipe.protein ?? 0).round()}g',
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _detailLine(recipe),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          recipe.prepTime != null ? '${recipe.prepTime} min' : 'Quick',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _detailLine(Recipe recipe) {
    final difficulty = recipe.difficulty?.trim();
    if (difficulty != null && difficulty.isNotEmpty) {
      return difficulty[0].toUpperCase() + difficulty.substring(1).toLowerCase();
    }
    return 'Smart AI pick';
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(
          color: color.withValues(alpha: 0.38),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, this.backgroundColor});

  final String label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  const _SuggestionPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.secondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Showing fallback recipes. Add a valid Spoonacular key to surface live recommendations.',
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: () async => onRefresh(), child: const Text('Refresh')),
        ],
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: const Center(
        child: Icon(Icons.restaurant_rounded, size: 42, color: Colors.white54),
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
              highlightColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
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
  const _HomeCategory({required this.label, required this.emoji, required this.color});

  final String label;
  final String emoji;
  final Color color;
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
