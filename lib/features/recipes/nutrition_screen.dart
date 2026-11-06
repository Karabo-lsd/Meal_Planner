import '../../core/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/recipe_card.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key, this.showBackButton = false});

  /// True when opened from the profile (no bottom navigation to leave with).
  final bool showBackButton;

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedRecipesAsync = ref.watch(savedRecipesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
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
          'Saved Recipes',
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
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your collection',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (savedRecipesAsync.valueOrNull case final recipes?)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${recipes.length} ${recipes.length == 1 ? 'recipe' : 'recipes'}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'Your favorite meals, ready when you are.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 16),
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
                if (_hasActiveFilters)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetSearch,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Clear Search'),
                    ),
                  ),
                Expanded(
                  child: savedRecipesAsync.when(
                    data: (savedRecipes) =>
                        _buildRecipeGrid(savedRecipes: savedRecipes),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Center(
                      child: Text('Unable to load your saved recipes.'),
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

  Widget _buildRecipeGrid({required List<Recipe> savedRecipes}) {
    final savedIds = ref.watch(savedRecipeIdsProvider);

    final filtered = savedRecipes.where((recipe) {
      final title = recipe.title.toLowerCase();
      if (_search.isEmpty) {
        return true;
      }
      final hasIngredient = (recipe.ingredients ?? const []).any(
        (i) => i.toLowerCase().contains(_search),
      );
      return title.contains(_search) || hasIngredient;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: GlassPanel(
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: Text(
            _search.isEmpty
                ? 'No saved recipes yet. Tap the heart on a recipe to keep it here.'
                : 'No saved recipes match your search.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          gridDelegate: recipeGridDelegate(
            recipeGridColumns(constraints.maxWidth),
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final recipe = filtered[index];
            return RecipeCard(
              recipe: recipe,
              isFavorite: savedIds.contains(recipe.id),
              onTap: () => Navigator.pushNamed(
                context,
                '/recipeDetail',
                arguments: recipe,
              ),
              onFavoriteTap: () => _toggleFavorite(recipe),
            );
          },
        );
      },
    );
  }

  bool get _hasActiveFilters => _search.isNotEmpty;

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _search = '';
    });
  }

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
}
