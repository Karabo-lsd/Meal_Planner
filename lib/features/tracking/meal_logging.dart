import 'package:flutter/material.dart';
import '../../core/friendly_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';

const mealSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

String defaultMealSlot() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'breakfast';
  if (hour < 15) return 'lunch';
  if (hour < 21) return 'dinner';
  return 'snack';
}

final _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Records [recipe] as eaten today and refreshes the dashboard totals.
Future<void> logRecipeEaten(
  WidgetRef ref,
  Recipe recipe, {
  required String slot,
  double servings = 1,
}) async {
  if (!_uuidRe.hasMatch(recipe.id)) {
    throw StateError(
      'This recipe has not been saved yet. Open it from your feed and try again.',
    );
  }
  await ref
      .read(mealServiceProvider)
      .logFood(
        mealSlot: slot,
        recipeId: recipe.id,
        source: 'recipe',
        quantity: servings,
        unit: 'serving',
        calories: recipe.calories == null ? null : recipe.calories! * servings,
        protein: recipe.protein == null ? null : recipe.protein! * servings,
        carbs: recipe.carbs == null ? null : recipe.carbs! * servings,
        fat: recipe.fat == null ? null : recipe.fat! * servings,
      );
  ref.invalidate(todayLogsProvider);
  ref.invalidate(goalProgressProvider);
  ref.invalidate(nutritionSummaryProvider);
}

/// Asks which meal and how many servings, then logs the recipe.
Future<void> showLogMealSheet(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe, {
  String? initialSlot,
}) async {
  var slot = initialSlot ?? defaultMealSlot();
  var servings = 1.0;
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log "${recipe.title}"',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in mealSlots)
                      ChoiceChip(
                        label: Text('${s[0].toUpperCase()}${s.substring(1)}'),
                        selected: slot == s,
                        onSelected: (_) => setState(() => slot = s),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Servings',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Decrease servings',
                      onPressed: servings > 0.5
                          ? () => setState(() => servings -= 0.5)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Semantics(
                      label: '$servings servings',
                      child: Text(
                        servings.toStringAsFixed(servings % 1 == 0 ? 0 : 1),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase servings',
                      onPressed: servings < 6
                          ? () => setState(() => servings += 0.5)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (recipe.calories != null)
                  Text(
                    '${(recipe.calories! * servings).round()} kcal total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('I ate this'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  if (confirmed != true) return;
  try {
    await logRecipeEaten(ref, recipe, slot: slot, servings: servings);
    messenger.showSnackBar(SnackBar(content: Text('Logged ${recipe.title}.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, action: 'log this meal'))));
  }
}
