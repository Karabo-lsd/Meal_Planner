import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';
import '../tracking/meal_logging.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key});

  Recipe _withDetails(Recipe base, Map<String, dynamic> details) {
    List<String> strings(Object? v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    final steps = strings(details['steps']);
    final ingredients = strings(details['ingredients']);
    final detailStepIngredients = (details['step_ingredients'] as List?)
        ?.map((step) => (step as List).map((item) => item.toString()).toList())
        .toList();
    final selectedSteps = (base.steps ?? const []).isNotEmpty
        ? base.steps!
        : steps;
    return Recipe(
      id: base.id,
      title: base.title,
      description: base.description,
      ingredients: ingredients.isNotEmpty ? ingredients : base.ingredients,
      steps: selectedSteps,
      stepIngredients: detailStepIngredients?.length == selectedSteps.length
          ? detailStepIngredients
          : base.stepIngredients,
      imageUrl: base.imageUrl,
      calories: base.calories ?? (details['calories'] as num?)?.round(),
      protein: base.protein ?? (details['protein'] as num?)?.toDouble(),
      carbs: base.carbs ?? (details['carbs'] as num?)?.toDouble(),
      fat: base.fat ?? (details['fat'] as num?)?.toDouble(),
      difficulty: base.difficulty,
      prepTime:
          base.prepTime ?? (details['prep_time_minutes'] as num?)?.round(),
      tags: base.tags,
      supportedDiets: base.supportedDiets,
      cuisine: base.cuisine,
      mealType: base.mealType,
      totalTimeMinutes: base.totalTimeMinutes,
      sourceProvider: base.sourceProvider,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseRecipe = ModalRoute.of(context)!.settings.arguments as Recipe?;

    if (baseRecipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: Text('Recipe not found.')),
      );
    }

    final detailsAsync = ref.watch(recipeDetailsProvider(baseRecipe.id));
    final recipe = _withDetails(
      baseRecipe,
      detailsAsync.valueOrNull ?? const <String, dynamic>{},
    );

    final imageUrl = recipe.imageUrl;
    final allTags = [
      ...?recipe.tags,
      ...?recipe.supportedDiets,
      if (recipe.cuisine != null) recipe.cuisine!,
    ].map((t) => _capitalize(t)).toSet().toList();
    final colorScheme = Theme.of(context).colorScheme;
    final panelColor = colorScheme.surface.withValues(alpha: 0.96);
    final panelBorder = colorScheme.outline.withValues(alpha: 0.34);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => showLogMealSheet(context, ref, recipe),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Log as eaten'),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: BackButton(color: colorScheme.onSurface),
        title: Text(
          recipe.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -70,
            child: Container(
              width: 230,
              height: 230,
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
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Hero image ────────────────────────────────
              GlassPanel(
                radius: 20,
                color: panelColor,
                borderColor: panelBorder,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : _imagePlaceholder(),
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Nutrition bar ──────────────────────────────
              GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                radius: 16,
                color: panelColor,
                borderColor: panelBorder,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    _macroTile(
                      context,
                      recipe.calories?.toString() ?? '—',
                      'kcal',
                      colorScheme.primary,
                    ),
                    _macroTile(
                      context,
                      recipe.protein == null
                          ? '—'
                          : '${recipe.protein!.toStringAsFixed(1)}g',
                      'Protein',
                      const Color(0xFF1E7F43),
                    ),
                    _macroTile(
                      context,
                      recipe.carbs == null
                          ? '—'
                          : '${recipe.carbs!.toStringAsFixed(1)}g',
                      'Carbs',
                      const Color(0xFF1E5E9A),
                    ),
                    _macroTile(
                      context,
                      recipe.fat == null
                          ? '—'
                          : '${recipe.fat!.toStringAsFixed(1)}g',
                      'Fat',
                      const Color(0xFF8A5A12),
                    ),
                    if (recipe.prepTime != null) ...[
                      _macroTile(
                        context,
                        '${recipe.prepTime}',
                        'min',
                        colorScheme.tertiary,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Tags ──────────────────────────────────────
              if (allTags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: allTags
                      .map(
                        (t) => Chip(
                          label: Text(
                            t,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          backgroundColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.78),
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.45),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Description ──────────────────────────────
              if ((recipe.description ?? '').isNotEmpty) ...[
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  color: panelColor,
                  borderColor: panelBorder,
                  child: Text(
                    recipe.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Ingredients ──────────────────────────────
              if ((recipe.ingredients ?? const []).isNotEmpty) ...[
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  color: panelColor,
                  borderColor: panelBorder,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recipe.ingredients!
                        .map(
                          (ing) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _capitalize(ing),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Steps / Instructions ────────────────────────
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if ((recipe.steps ?? const []).isEmpty && detailsAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if ((recipe.steps ?? const []).isEmpty)
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  color: panelColor,
                  borderColor: panelBorder,
                  child: Text(
                    'Detailed steps are not available for this recipe.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                )
              else
                Column(
                  children: recipe.steps!.asMap().entries.map((entry) {
                    final stepIngredients =
                        recipe.stepIngredients != null &&
                            entry.key < recipe.stepIngredients!.length
                        ? recipe.stepIngredients![entry.key]
                        : const <String>[];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 38,
                                child: Text(
                                  '${entry.key + 1}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.value,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.w800,
                                            height: 1.35,
                                          ),
                                    ),
                                    if (stepIngredients.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ...stepIngredients.map(
                                        (ingredient) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 3,
                                          ),
                                          child: Text(
                                            _capitalize(ingredient),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.62),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (entry.key < recipe.steps!.length - 1)
                          Divider(
                            height: 1,
                            color: colorScheme.outline.withValues(alpha: 0.28),
                          ),
                      ],
                    );
                  }).toList(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    height: 220,
    color: const Color(0xFFD4E8D7),
    child: const Center(
      child: Icon(Icons.fastfood, size: 68, color: Color(0xFF224A2E)),
    ),
  );

  Widget _macroTile(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
