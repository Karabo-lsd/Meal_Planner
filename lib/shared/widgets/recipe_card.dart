import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/models/recipe.dart';

/// Grid layout shared by the home feed and the saved recipes screen so recipe
/// cards look identical everywhere.
SliverGridDelegateWithFixedCrossAxisCount recipeGridDelegate(
  int crossAxisCount,
) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: 14,
    mainAxisSpacing: 14,
    childAspectRatio: crossAxisCount >= 4
        ? 0.74
        : crossAxisCount == 3
        ? 0.68
        : 0.62,
  );
}

int recipeGridColumns(double width) => width >= 1000
    ? 4
    : width >= 700
    ? 3
    : 2;

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Recipe recipe;
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
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    child: RecipeImage(
                      imageUrl: recipe.imageUrl,
                      placeholderColor: colorScheme.surfaceContainerHighest,
                    ),
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
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.redAccent : Colors.white,
                      ),
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
                        MetricPill(
                          icon: Icons.local_fire_department_rounded,
                          label: recipe.calories == null
                              ? '— kcal'
                              : '${recipe.calories} kcal',
                          color: colorScheme.tertiary,
                        ),
                        MetricPill(
                          icon: Icons.fitness_center_rounded,
                          label: recipe.protein == null
                              ? '—'
                              : '${recipe.protein!.round()}g protein',
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          recipe.prepTime != null
                              ? '${recipe.prepTime} min'
                              : 'Time N/A',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
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
      return difficulty[0].toUpperCase() +
          difficulty.substring(1).toLowerCase();
    }
    final cuisine = recipe.cuisine?.trim();
    if (cuisine != null && cuisine.isNotEmpty) {
      return cuisine;
    }
    return 'Recipe';
  }
}

class MetricPill extends StatelessWidget {
  const MetricPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.38)),
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

class RecipeImagePlaceholder extends StatelessWidget {
  const RecipeImagePlaceholder({super.key, required this.color});

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

class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.imageUrl,
    required this.placeholderColor,
  });

  final String? imageUrl;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return RecipeImagePlaceholder(color: placeholderColor);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // Decode at card size rather than full resolution.
      memCacheWidth: 600,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, _) => Shimmer.fromColors(
        baseColor: placeholderColor,
        highlightColor: placeholderColor.withValues(alpha: 0.5),
        child: Container(color: placeholderColor),
      ),
      errorWidget: (context, _, _) =>
          RecipeImagePlaceholder(color: placeholderColor),
    );
  }
}
