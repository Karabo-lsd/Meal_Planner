import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key, this.onBackToHome});

  final VoidCallback? onBackToHome;

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final _tabs = ['Recommended', 'Quick Meals', 'Breakfast', 'Liked Meals'];
  final TextEditingController _searchController = TextEditingController();
  int _activeTab = 0;
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final savedRecipesAsync = ref.watch(savedRecipesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
              return;
            }
            widget.onBackToHome?.call();
          },
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/pantry'),
            icon: Icon(Icons.kitchen, color: colorScheme.onSurface),
            tooltip: 'Pantry',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/dietaryProfile'),
            icon: Icon(Icons.tune, color: colorScheme.onSurface),
            tooltip: 'Dietary Profile',
          ),
        ],
        title: Text(
          'Nutrition & Recipes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.2),
                    colorScheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.16),
                    colorScheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.78),
                      ),
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  radius: 24,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search recipes or ingredients',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF5A6E5D),
                      ),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF5A6E5D),
                              ),
                              onPressed: _resetSearch,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) {
                      final isActive = index == _activeTab;
                      return GestureDetector(
                        onTap: () => setState(() => _activeTab = index),
                        child: GlassPanel(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          radius: 22,
                          color: isActive
                              ? colorScheme.primary.withValues(alpha: 0.86)
                              : colorScheme.surface.withValues(alpha: 0.6),
                          borderColor: isActive
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.18),
                          child: Text(
                            _tabs[index],
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : colorScheme.onSurface.withValues(alpha: 0.7),
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: pantry
                      .take(6)
                      .map(
                        (ingredient) => GlassPanel(
                          radius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(ingredient.name),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                if (_hasActiveFilters)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Reset Filters'),
                    ),
                  ),
                Expanded(
                  child: recommendationsAsync.when(
                    data: (recipes) => savedRecipesAsync.when(
                      data: (savedRecipes) => _buildRecipeGrid(
                        recommendations: recipes,
                        savedRecipes: savedRecipes,
                      ),
                      loading: () {
                        if (_activeTab == 3) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return _buildRecipeGrid(
                          recommendations: recipes,
                          savedRecipes: const <Recipe>[],
                        );
                      },
                      error: (_, stackTrace) => _buildRecipeGrid(
                        recommendations: recipes,
                        savedRecipes: const <Recipe>[],
                      ),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Center(
                      child: Text('Unable to load recommendations.'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeGrid({
    required List<Recipe> recommendations,
    required List<Recipe> savedRecipes,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = _activeTab == 3
        ? savedRecipes
        : _withShowcaseRecipes(recommendations);
    final savedIds = ref.watch(savedRecipeIdsProvider);

    final filtered = source.where((recipe) {
      final title = recipe.title.toLowerCase();
      final tags = (recipe.tags ?? const []).map(_normalize).toSet();

      final tabOk = switch (_activeTab) {
        0 => true,
        1 =>
          (recipe.prepTime ?? 999) <= 20 ||
              tags.contains('quick') ||
              tags.contains('quick meals') ||
              title.contains('quick'),
        2 => tags.contains('breakfast') || title.contains('breakfast'),
        3 => true,
        _ => true,
      };

      if (_search.isEmpty) {
        return tabOk;
      }
      final hasIngredient = (recipe.ingredients ?? const []).any(
        (i) => i.toLowerCase().contains(_search),
      );
      return tabOk && (title.contains(_search) || hasIngredient);
    }).toList();

    if (_activeTab == 3 && filtered.isEmpty) {
      return Center(
        child: GlassPanel(
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: Text(
            'No liked meals yet. Tap the heart on any meal to save it for later.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 600 ? 3 : 2;
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 2 ? 0.64 : 0.72,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final recipe = filtered[index];
            final isFavorite = savedIds.contains(recipe.id);
            return GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/recipeDetail', arguments: recipe);
              },
              child: GlassPanel(
                radius: 22,
                color: colorScheme.surface.withValues(alpha: 0.96),
                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.82),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 96,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: _recipeImageFallback(colorScheme),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              recipe.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                            ),
                            onPressed: () => _toggleFavorite(recipe),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${recipe.calories ?? 0} kcal',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            recipe.prepTime != null ? '${recipe.prepTime} min' : '10 min',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool get _hasActiveFilters => _search.isNotEmpty || _activeTab != 0;

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _search = '';
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _search = '';
      _activeTab = 0;
    });
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ').trim();
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    await ref.read(savedRecipeIdsProvider.notifier).toggle(recipe.id);
    ref.invalidate(savedRecipesProvider);
  }

  List<Recipe> _withShowcaseRecipes(List<Recipe> recipes) {
    final byId = <String, Recipe>{
      for (final recipe in recipes) recipe.id: recipe,
    };

    final previewRecipes = <Recipe>[
      Recipe(
        id: 'preview-recipes-1',
        title: 'Spicy Tofu Rainbow Bowl',
        description: 'Tofu, quinoa, peppers, and sesame greens.',
        calories: 540,
        protein: 30,
        prepTime: 18,
        tags: ['Lunch', 'Vegetarian', 'Healthy'],
      ),
      Recipe(
        id: 'preview-recipes-2',
        title: 'Overnight Berry Oats',
        description: 'Rolled oats, berries, chia, and Greek yogurt.',
        calories: 390,
        protein: 20,
        prepTime: 10,
        tags: ['Breakfast', 'Quick Meals'],
      ),
    ];

    for (final preview in previewRecipes) {
      byId.putIfAbsent(preview.id, () => preview);
    }

    return byId.values.toList();
  }

  Widget _recipeImageFallback(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.82),
            colorScheme.secondaryContainer.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fastfood,
          size: 40,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
