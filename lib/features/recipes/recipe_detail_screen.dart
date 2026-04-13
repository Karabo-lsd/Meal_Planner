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

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        title: Text(
          recipe.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66D9CAFF), Color(0x00D9CAFF)],
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // ── Hero image ────────────────────────────────
              GlassPanel(
                radius: 20,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _macroTile(context, '${recipe.calories ?? 0}',
                        'kcal', const Color(0xFF5B8DEF)),
                    _divider(),
                    _macroTile(
                        context,
                        '${(recipe.protein ?? 0).toStringAsFixed(1)}g',
                        'Protein',
                        const Color(0xFF58C27D)),
                    _divider(),
                    _macroTile(
                        context,
                        '${(recipe.carbs ?? 0).toStringAsFixed(1)}g',
                        'Carbs',
                        const Color(0xFFEF9B5B)),
                    _divider(),
                    _macroTile(
                        context,
                        '${(recipe.fat ?? 0).toStringAsFixed(1)}g',
                        'Fat',
                        const Color(0xFFE06C8A)),
                    if (recipe.prepTime != null) ...[  
                      _divider(),
                      _macroTile(
                          context,
                          '${recipe.prepTime}',
                          'min',
                          const Color(0xFF9B8DEF)),
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
                            label: Text(t,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                const Color(0x66E8EEFF),
                            side: const BorderSide(
                                color: Color(0x55A0AACC)),
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
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  child: Text(
                    recipe.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
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
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
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
                                  const Text('• ',
                                      style: TextStyle(
                                          color: Color(0xFF5B8DEF),
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      _capitalize(ing),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
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
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if ((recipe.steps ?? const []).isEmpty)
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  child: Text(
                    'Detailed steps are not available for this recipe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                GlassPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
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
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF5B8DEF),
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
                                          .bodyMedium,
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
        color: const Color(0xFFEFF4FF),
        child: const Center(
          child: Icon(Icons.fastfood, size: 68, color: Color(0xFF57637B)),
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
                ?.copyWith(color: const Color(0xFF7D8799))),
      ],
    );
  }

  Widget _divider() => const SizedBox(
      height: 32,
      child: VerticalDivider(width: 1, color: Color(0x44000000)));

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}