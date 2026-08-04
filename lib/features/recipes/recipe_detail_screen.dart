import 'package:flutter/material.dart';

import '../../core/models/recipe.dart';
import '../../shared/widgets/glass_panel.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipe =
        ModalRoute.of(context)!.settings.arguments as Recipe?;

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: Text('Recipe not found.')),
      );
    }

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
                              progress == null
                                  ? child
                                  : _imagePlaceholder(),
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Nutrition bar ──────────────────────────────
              GlassPanel(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                radius: 16,
                color: panelColor,
                borderColor: panelBorder,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 12,
                  spacing: 12,
                  children: [
                    _macroTile(context, '${recipe.calories ?? 0}',
                        'kcal', colorScheme.primary),
                    _macroTile(
                        context,
                        '${(recipe.protein ?? 0).toStringAsFixed(1)}g',
                        'Protein',
                        const Color(0xFF1E7F43)),
                    _macroTile(
                        context,
                        '${(recipe.carbs ?? 0).toStringAsFixed(1)}g',
                        'Carbs',
                        const Color(0xFF1E5E9A)),
                    _macroTile(
                        context,
                        '${(recipe.fat ?? 0).toStringAsFixed(1)}g',
                        'Fat',
                        const Color(0xFF8A5A12)),
                    if (recipe.prepTime != null) ...[
                      _macroTile(
                          context,
                          '${recipe.prepTime}',
                          'min',
                          colorScheme.tertiary),
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
                      .map((t) => Chip(
                            label: Text(
                              t,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            backgroundColor:
                              colorScheme.primaryContainer.withValues(alpha: 0.78),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.45)),
                            visualDensity:
                                VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Description ──────────────────────────────
              if ((recipe.description ?? '').isNotEmpty) ...[  
                Text('About',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        )),
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
                Text('Ingredients',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        )),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  color: panelColor,
                  borderColor: panelBorder,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recipe.ingredients!
                        .map((ing) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                    Text('• ',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      _capitalize(ing),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: colorScheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Steps / Instructions ────────────────────────
              Text('Instructions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      )),
              const SizedBox(height: 8),
              if ((recipe.steps ?? const []).isEmpty)
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
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  color: panelColor,
                  borderColor: panelBorder,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recipe.steps!
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    margin: const EdgeInsets.only(
                                        right: 10, top: 1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.primary,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${e.key + 1}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: colorScheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
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
      BuildContext context, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78))),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}