import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/ingredient.dart';
import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/glass_panel.dart';

enum _GroceryGroupingMode { category, goal }

class GroceryScreen extends ConsumerStatefulWidget {
  const GroceryScreen({super.key});

  @override
  ConsumerState<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends ConsumerState<GroceryScreen> {
  _GroceryGroupingMode _groupingMode = _GroceryGroupingMode.category;
  final Set<String> _checkedItems = <String>{};
  final List<_ShoppingItem> _manualItems = <_ShoppingItem>[];
  final Set<String> _hiddenItems = <String>{};
  bool _isEditingGroceries = false;
  bool _isGeneratingPlan = false;

  static const _kManualItems = 'manual_grocery_items';
  static const _kHiddenItems = 'hidden_grocery_items';
  static const _kCompletedGroceries = 'completed_grocery_runs';

  @override
  void initState() {
    super.initState();
    _loadCheckedItems();
    _loadCustomGroceryState();
  }

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  void _loadCheckedItems() {
    final userId = _userId;
    if (userId == null) return;
    final cached = SessionStorage.loadCheckedGroceries(userId);
    if (cached == null || cached.isEmpty) return;
    _checkedItems
      ..clear()
      ..addAll(cached);
  }

  void _saveCheckedItems() {
    final userId = _userId;
    if (userId == null) return;
    SessionStorage.saveCheckedGroceries(userId, _checkedItems);
  }

  void _loadCustomGroceryState() {
    final userId = _userId;
    if (userId == null) return;

    final manualRaw = SessionStorage.load(userId, _kManualItems);
    if (manualRaw is List) {
      _manualItems
        ..clear()
        ..addAll(
          manualRaw
              .whereType<Map>()
              .map(
                (row) => _ShoppingItem(
                  name: (row['name'] ?? '').toString().trim(),
                  category: (row['category'] ?? 'Essentials').toString().trim(),
                  goal: (row['goal'] ?? 'General wellness').toString().trim(),
                ),
              )
              .where((item) => item.name.isNotEmpty),
        );
    }

    final hiddenRaw = SessionStorage.load(userId, _kHiddenItems);
    if (hiddenRaw is List) {
      _hiddenItems
        ..clear()
        ..addAll(
          hiddenRaw
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty),
        );
    }
  }

  void _saveCustomGroceryState() {
    final userId = _userId;
    if (userId == null) return;

    SessionStorage.save(
      userId,
      _kManualItems,
      _manualItems
          .map(
            (item) => {
              'name': item.name,
              'category': item.category,
              'goal': item.goal,
            },
          )
          .toList(),
    );
    SessionStorage.save(userId, _kHiddenItems, _hiddenItems.toList());
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final profile = ref.watch(dietaryProfileProvider);
    final recommendations = ref.watch(recommendationsProvider);
    final activePlan = ref.watch(activeMealPlanProvider);
    final activePlanItems = ref.watch(activeMealPlanItemsProvider);
    final dietType = _readDietType(profile);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Meal Planner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
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
            bottom: -110,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.18),
                    colorScheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: recommendations.when(
              data: (recipes) {
                final generatedItems = _withShowcaseShoppingItems(
                  _buildShoppingItems(
                    recipes: recipes,
                    pantry: pantry,
                    dietType: dietType,
                  ),
                );
                final shoppingItems = _buildEffectiveShoppingItems(generatedItems);
                final grouped = _groupItems(shoppingItems, _groupingMode);
                final shoppingCompleted =
                    shoppingItems.isNotEmpty &&
                    shoppingItems.every(
                      (item) => _checkedItems.contains(item.name.toLowerCase()),
                    );

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    GlassPanel(
                      radius: 24,
                      padding: const EdgeInsets.all(18),
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderColor: colorScheme.primary.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Weekly Meal Plan',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _isGeneratingPlan
                                    ? null
                                    : () => _generateWeeklyPlan(
                                          recipes: recipes,
                                          pantry: pantry,
                                        ),
                                icon: _isGeneratingPlan
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_awesome),
                                label: Text(_isGeneratingPlan ? 'Generating...' : 'Generate'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          activePlan.when(
                            data: (plan) {
                              if (plan == null) {
                                return Text(
                                  'No active plan yet. Generate one to start tracking meals for the week.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                );
                              }
                              return Text(
                                'Active plan: ${plan['start_date']} to ${plan['end_date']}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => Text(
                              'Unable to load active meal plan.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 10),
                          activePlanItems.when(
                            data: (items) {
                              if (items.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final preview = items.take(3).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upcoming items',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...preview.map(
                                    (item) {
                                      final recipe = item['recipes'] as Map<String, dynamic>?;
                                      final food = item['foods_master'] as Map<String, dynamic>?;
                                      final title = recipe?['title']?.toString() ??
                                          food?['canonical_name']?.toString() ??
                                          'Planned meal';
                                      final date = (item['plan_date'] ?? item['date'])?.toString() ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                          '$date  $title',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      radius: 24,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended groceries for your next shop',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use this list to buy what your meal recommendations need. Items are grouped by category or your goal focus.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      radius: 20,
                      padding: const EdgeInsets.all(12),
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      borderColor: colorScheme.secondary.withValues(alpha: 0.42),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditingGroceries = !_isEditingGroceries;
                              });
                            },
                            icon: Icon(
                              _isEditingGroceries ? Icons.check : Icons.edit_outlined,
                            ),
                            label: Text(
                              _isEditingGroceries ? 'Done Editing' : 'Edit Grocery',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showAddGroceryDialog(dietType),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _clearVisibleGroceries(shoppingItems),
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('Clear Grocery'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (shoppingCompleted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassPanel(
                          radius: 20,
                          padding: const EdgeInsets.all(14),
                          color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                          borderColor: colorScheme.tertiary.withValues(alpha: 0.42),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shopping complete',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You checked all items. Save this run or clear the grocery list for your next trip.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () => _saveCompletedShopping(shoppingItems),
                                      icon: const Icon(Icons.save_outlined),
                                      label: const Text('Save Completed'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _clearVisibleGroceries(shoppingItems),
                                      icon: const Icon(Icons.clear_all),
                                      label: const Text('Clear Grocery'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    GlassPanel(
                      radius: 20,
                      padding: const EdgeInsets.all(10),
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
                      borderColor: colorScheme.primary.withValues(alpha: 0.22),
                      child: SegmentedButton<_GroceryGroupingMode>(
                        segments: const [
                          ButtonSegment<_GroceryGroupingMode>(
                            value: _GroceryGroupingMode.category,
                            icon: Icon(Icons.category_outlined),
                            label: Text('By category'),
                          ),
                          ButtonSegment<_GroceryGroupingMode>(
                            value: _GroceryGroupingMode.goal,
                            icon: Icon(Icons.flag_outlined),
                            label: Text('By health goal'),
                          ),
                        ],
                        selected: <_GroceryGroupingMode>{_groupingMode},
                        onSelectionChanged: (value) {
                          setState(() {
                            _groupingMode = value.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassPanel(
                      radius: 20,
                      padding: const EdgeInsets.all(14),
                      color: colorScheme.primaryContainer.withValues(alpha: 0.38),
                      borderColor: colorScheme.primary.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryPill(
                              icon: Icons.shopping_cart_checkout,
                              label: 'To buy',
                              value: shoppingItems.length.toString(),
                              accent: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryPill(
                              icon: Icons.check_circle_outline,
                              label: 'Checked',
                              value: _checkedItems.length.toString(),
                              accent: const Color(0xFF2E9F57),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryPill(
                              icon: Icons.kitchen_outlined,
                              label: 'In pantry',
                              value: pantry.length.toString(),
                              accent: const Color(0xFF0A7EA4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (shoppingItems.isEmpty)
                      GlassPanel(
                        radius: 20,
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'Great job. Your pantry already covers current recommendations. Scan meals or refresh your profile for a new grocery list.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      )
                    else
                      ...grouped.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: GlassPanel(
                            radius: 20,
                            padding: const EdgeInsets.all(14),
                            color: colorScheme.surface.withValues(alpha: 0.94),
                            borderColor: colorScheme.primary.withValues(alpha: 0.24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...entry.value.map(
                                  (item) => _GroceryItemTile(
                                    item: item,
                                    editMode: _isEditingGroceries,
                                    checked: _checkedItems.contains(item.name.toLowerCase()),
                                    onRemove: () => _removeGroceryItem(item),
                                    onToggle: () {
                                      setState(() {
                                        final key = item.name.toLowerCase();
                                        if (_checkedItems.contains(key)) {
                                          _checkedItems.remove(key);
                                        } else {
                                          _checkedItems.add(key);
                                        }
                                      });
                                      _saveCheckedItems();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  GlassPanel(
                    radius: 20,
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Unable to load recommendation-based groceries right now. Your pantry has ${pantry.length} items available for planning.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _readDietType(Map<String, dynamic> profile) {
    final root = profile['diet_type']?.toString().trim();
    if (root != null && root.isNotEmpty) {
      return root;
    }

    final preferences = profile['preferences'];
    if (preferences is Map) {
      final diet = preferences['diet']?.toString().trim();
      if (diet != null && diet.isNotEmpty) {
        return diet;
      }
    }

    return 'balanced';
  }

  List<_ShoppingItem> _buildShoppingItems({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
    required String dietType,
  }) {
    final pantryNames = pantry
        .map((item) => item.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final byName = <String, _ShoppingItem>{};

    for (final recipe in recipes) {
      final ingredients = recipe.ingredients ?? const <String>[];
      for (final rawIngredient in ingredients) {
        final normalized = rawIngredient.trim().toLowerCase();
        if (normalized.isEmpty || pantryNames.contains(normalized)) {
          continue;
        }

        byName.putIfAbsent(
          normalized,
          () => _ShoppingItem(
            name: rawIngredient.trim(),
            category: _inferCategory(rawIngredient),
            goal: _inferGoal(rawIngredient, dietType, recipe),
          ),
        );
      }
    }

    return byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<_ShoppingItem> _buildEffectiveShoppingItems(List<_ShoppingItem> generatedItems) {
    final byName = <String, _ShoppingItem>{
      for (final item in generatedItems) item.name.toLowerCase(): item,
    };

    for (final manual in _manualItems) {
      byName[manual.name.toLowerCase()] = manual;
    }

    for (final hidden in _hiddenItems) {
      byName.remove(hidden);
    }

    final merged = byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  List<_ShoppingItem> _withShowcaseShoppingItems(List<_ShoppingItem> items) {
    final byName = <String, _ShoppingItem>{
      for (final item in items) item.name.toLowerCase(): item,
    };

    const previewItems = <_ShoppingItem>[
      _ShoppingItem(name: 'Chicken breast', category: 'Protein', goal: 'High protein'),
      _ShoppingItem(name: 'Greek yogurt', category: 'Dairy', goal: 'High protein'),
      _ShoppingItem(name: 'Spinach', category: 'Vegetables', goal: 'Micronutrient support'),
      _ShoppingItem(name: 'Broccoli', category: 'Vegetables', goal: 'Micronutrient support'),
      _ShoppingItem(name: 'Brown rice', category: 'Grains & starches', goal: 'Energy balance'),
      _ShoppingItem(name: 'Quinoa', category: 'Grains & starches', goal: 'Energy balance'),
      _ShoppingItem(name: 'Blueberries', category: 'Fruits', goal: 'General wellness'),
      _ShoppingItem(name: 'Avocado', category: 'Fruits', goal: 'General wellness'),
      _ShoppingItem(name: 'Olive oil', category: 'Healthy fats', goal: 'General wellness'),
      _ShoppingItem(name: 'Almonds', category: 'Healthy fats', goal: 'General wellness'),
    ];

    for (final item in previewItems) {
      byName.putIfAbsent(item.name.toLowerCase(), () => item);
    }

    final merged = byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  Map<String, List<_ShoppingItem>> _groupItems(
    List<_ShoppingItem> items,
    _GroceryGroupingMode mode,
  ) {
    final map = <String, List<_ShoppingItem>>{};
    for (final item in items) {
      final key = mode == _GroceryGroupingMode.category ? item.category : item.goal;
      map.putIfAbsent(key, () => <_ShoppingItem>[]).add(item);
    }

    for (final value in map.values) {
      value.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  String _inferCategory(String ingredientName) {
    final name = ingredientName.toLowerCase();
    if (_containsAny(name, const ['chicken', 'beef', 'turkey', 'salmon', 'tuna', 'egg'])) {
      return 'Protein';
    }
    if (_containsAny(name, const ['milk', 'yogurt', 'cheese'])) {
      return 'Dairy';
    }
    if (_containsAny(name, const ['spinach', 'lettuce', 'broccoli', 'carrot', 'pepper', 'onion'])) {
      return 'Vegetables';
    }
    if (_containsAny(name, const ['apple', 'banana', 'berry', 'orange', 'avocado'])) {
      return 'Fruits';
    }
    if (_containsAny(name, const ['rice', 'oat', 'pasta', 'bread', 'quinoa', 'potato'])) {
      return 'Grains & starches';
    }
    if (_containsAny(name, const ['oil', 'almond', 'walnut', 'peanut', 'seed'])) {
      return 'Healthy fats';
    }
    return 'Essentials';
  }

  String _inferGoal(String ingredientName, String dietType, Recipe recipe) {
    final name = ingredientName.toLowerCase();
    if (_containsAny(name, const ['chicken', 'egg', 'salmon', 'tuna', 'greek yogurt', 'tofu'])) {
      return 'High protein';
    }
    if (_containsAny(name, const ['spinach', 'broccoli', 'berry', 'avocado'])) {
      return 'Micronutrient support';
    }
    if (_containsAny(name, const ['oat', 'brown rice', 'quinoa', 'sweet potato'])) {
      return 'Energy balance';
    }

    final supportsDiet = (recipe.supportedDiets ?? const <String>[])
        .map((e) => e.toLowerCase())
        .contains(dietType.toLowerCase());
    if (supportsDiet) {
      return '${_titleCaseDiet(dietType)} plan';
    }

    return 'General wellness';
  }

  String _titleCaseDiet(String dietType) {
    return dietType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  bool _containsAny(String value, List<String> tokens) {
    for (final token in tokens) {
      if (value.contains(token)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _showAddGroceryDialog(String dietType) async {
    final controller = TextEditingController();

    final addedName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add grocery item'),
          content: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Item name',
              hintText: 'e.g. Tomatoes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (!mounted || addedName == null) return;
    final normalized = addedName.trim();
    if (normalized.isEmpty) return;

    final key = normalized.toLowerCase();
    setState(() {
      _hiddenItems.remove(key);
      _manualItems.removeWhere((item) => item.name.toLowerCase() == key);
      _manualItems.add(
        _ShoppingItem(
          name: normalized,
          category: _inferCategory(normalized),
          goal: '${_titleCaseDiet(dietType)} plan',
        ),
      );
    });
    _saveCustomGroceryState();
  }

  void _removeGroceryItem(_ShoppingItem item) {
    final key = item.name.toLowerCase();
    setState(() {
      _hiddenItems.add(key);
      _manualItems.removeWhere((manual) => manual.name.toLowerCase() == key);
      _checkedItems.remove(key);
    });
    _saveCheckedItems();
    _saveCustomGroceryState();
  }

  void _clearVisibleGroceries(List<_ShoppingItem> shoppingItems) {
    if (shoppingItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to clear right now.')),
      );
      return;
    }

    setState(() {
      for (final item in shoppingItems) {
        final key = item.name.toLowerCase();
        _hiddenItems.add(key);
        _checkedItems.remove(key);
      }
      _manualItems.removeWhere(
        (item) => _hiddenItems.contains(item.name.toLowerCase()),
      );
    });
    _saveCheckedItems();
    _saveCustomGroceryState();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grocery list cleared.')),
    );
  }

  void _saveCompletedShopping(List<_ShoppingItem> shoppingItems) {
    final completed = shoppingItems
        .where((item) => _checkedItems.contains(item.name.toLowerCase()))
        .toList();
    if (completed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check items before saving completed shopping.')),
      );
      return;
    }

    final userId = _userId;
    if (userId != null) {
      final existing = SessionStorage.load(userId, _kCompletedGroceries);
      final history = (existing is List)
          ? List<dynamic>.from(existing)
          : <dynamic>[];
      history.add({
        'saved_at': DateTime.now().toIso8601String(),
        'items': completed
            .map((item) => {'name': item.name, 'category': item.category, 'goal': item.goal})
            .toList(),
      });
      SessionStorage.save(userId, _kCompletedGroceries, history);
    }

    setState(() {
      for (final item in completed) {
        final key = item.name.toLowerCase();
        _hiddenItems.add(key);
        _checkedItems.remove(key);
      }
      _manualItems.removeWhere(
        (item) => _hiddenItems.contains(item.name.toLowerCase()),
      );
      _isEditingGroceries = false;
    });
    _saveCheckedItems();
    _saveCustomGroceryState();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Completed shopping saved. Purchased items cleared.')),
    );
  }

  Future<void> _generateWeeklyPlan({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
  }) async {
    if (_isGeneratingPlan) return;
    setState(() {
      _isGeneratingPlan = true;
    });

    try {
      await ref
          .read(mealPlanServiceProvider)
          .createWeeklyPlan(recipes: recipes, pantry: pantry);
      ref.invalidate(activeMealPlanProvider);
      ref.invalidate(activeMealPlanItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly meal plan generated.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.contains('Unable to generate a plan')
                ? 'Could not generate plan yet. Add pantry items or refresh recommendations, then try again.'
                : 'Could not generate meal plan: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isGeneratingPlan = false;
      });
    }
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 110,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.24),
              accent.withValues(alpha: 0.12),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingItem {
  const _ShoppingItem({
    required this.name,
    required this.category,
    required this.goal,
  });

  final String name;
  final String category;
  final String goal;
}

class _GroceryItemTile extends StatelessWidget {
  const _GroceryItemTile({
    required this.item,
    required this.editMode,
    required this.checked,
    required this.onToggle,
    required this.onRemove,
  });

  final _ShoppingItem item;
  final bool editMode;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: checked
                ? const Color(0xFF2E9F57).withValues(alpha: 0.14)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: checked
                  ? const Color(0xFF2E9F57).withValues(alpha: 0.45)
                  : colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            decoration: checked ? TextDecoration.lineThrough : null,
                            color: checked
                          ? const Color(0xFF1F6F3E)
                                : null,
                          ),
                    ),
                    Text(
                      '${item.category} | ${item.goal}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                    ),
                  ],
                ),
              ),
              if (editMode)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove item',
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'Week';

  static const Map<String, Object> _chartData = {
    'Day': {
      'calories': 1850,
      'bars': [0.55, 0.72, 0.48, 0.86, 0.63, 0.95, 0.78],
      'labels': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    },
    'Week': {
      'calories': 2343,
      'bars': [0.42, 0.60, 0.78, 0.71, 0.89, 0.52, 0.75],
      'labels': ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'],
    },
    'Month': {
      'calories': 2400,
      'bars': [0.50, 0.63, 0.72, 0.66, 0.80, 0.76, 0.84],
      'labels': ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6', 'Week 7'],
    },
  };

  @override
  Widget build(BuildContext context) {
    final data = _chartData[_selectedPeriod] as Map<String, Object>;
    final totalCalories = data['calories'] as int;
    final bars = data['bars'] as List<double>;
    final labels = data['labels'] as List<String>;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Nutrition Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
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
            bottom: -110,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.18),
                    colorScheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildSummaryHeader(context),
                const SizedBox(height: 18),
                _buildStatusCards(context),
                const SizedBox(height: 24),
                _buildPeriodSelector(context),
                const SizedBox(height: 18),
                _buildCalorieChart(context, totalCalories, bars, labels),
                const SizedBox(height: 22),
                _buildMacroBreakdown(context),
                const SizedBox(height: 22),
                _buildRecentMeals(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calorie Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track your intake across multiple periods and spot trends in your meals.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primary,
          child: const Icon(Icons.bar_chart_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStatusCards(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildStatusCard(context, 'Today', '1,850 kcal', 'Goal 2,200')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatusCard(context, 'Weekly Avg', '2,150 kcal', 'On track')),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, String title, String value, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: ['Day', 'Week', 'Month'].map((period) {
        final isSelected = period == _selectedPeriod;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onSelected: (_) {
                setState(() {
                  _selectedPeriod = period;
                });
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalorieChart(BuildContext context, int totalCalories, List<double> bars, List<String> labels) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calorie Intake',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '$totalCalories kcal',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 120 * bars[index],
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          labels[index],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Calories shown are simulated preview data for your current period.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBreakdown(BuildContext context) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro Breakdown',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroTile(context, 'Protein', '72g', Theme.of(context).colorScheme.primary),
              _buildMacroTile(
                context,
                'Carbs',
                '210g',
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.82),
              ),
              _buildMacroTile(
                context,
                'Fat',
                '82g',
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.66),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTile(BuildContext context, String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color.lerp(color, colorScheme.surface, 0.84),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                label == 'Protein'
                    ? Icons.fitness_center
                    : label == 'Carbs'
                        ? Icons.grain
                        : Icons.local_fire_department,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMeals(BuildContext context) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Meals',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          _buildMealTile(context, 'Avocado toast', '420 kcal • 18g protein'),
          const SizedBox(height: 12),
          _buildMealTile(context, 'Chicken salad', '610 kcal • 39g protein'),
          const SizedBox(height: 12),
          _buildMealTile(context, 'Oat smoothie', '320 kcal • 12g protein'),
        ],
      ),
    );
  }

  Widget _buildMealTile(BuildContext context, String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.restaurant_menu_rounded, color: colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}
