import 'package:flutter/material.dart';
import '../../core/friendly_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/ingredient.dart';
import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../services/recommendation_service.dart';
import '../../services/session_storage.dart';
import '../../shared/widgets/glass_panel.dart';
import '../tracking/meal_logging.dart';

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
    final activePlan = ref.watch(activeMealPlanProvider);
    final activePlanItems = ref.watch(activeMealPlanItemsProvider);
    final dietType = _readDietType(profile);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [Tab(text: 'Meal plan'), Tab(text: 'Groceries')],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPlanTab(context, activePlan, activePlanItems),
                        _buildGroceriesTab(
                          context,
                          activePlanItems,
                          pantry,
                          dietType,
                        ),
                      ],
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

  static const _slotOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  String? _selectedDate;

  Recipe _recipeFromPlanItem(Map<String, dynamic> item) {
    final raw = item['recipes'];
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'id': item['recipe_id'] ?? '', 'title': 'Planned meal'};
    final nutrition = map['recipe_nutrition'];
    if (nutrition is List) {
      map['recipe_nutrition'] = nutrition.isNotEmpty ? nutrition.first : null;
    }
    if (map['recipe_nutrition'] == null) {
      map['calories'] ??= item['calories_estimate'];
      map['protein'] ??= item['protein_estimate'];
      map['carbs'] ??= item['carbs_estimate'];
      map['fat'] ??= item['fat_estimate'];
    }
    return Recipe.fromJson(map);
  }

  Widget _emptyPanel(BuildContext context, String message) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _buildPlanTab(
    BuildContext context,
    AsyncValue<Map<String, dynamic>?> activePlan,
    AsyncValue<List<Map<String, dynamic>>> planItems,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(dietaryProfileProvider);
    final target = (profile['daily_calorie_target'] as num?)?.toDouble();
    final eatenKeys = (ref.watch(todayLogsProvider).valueOrNull ?? const [])
        .map((log) => '${log['recipe_id']}|${log['meal_slot']}')
        .toSet();
    final today = DateTime.now().toIso8601String().split('T').first;

    final plan = activePlan.valueOrNull;
    final rangeLabel = plan == null
        ? 'No plan yet. Tap Generate and the AI builds one from your profile.'
        : '${DateFormat('EEE d MMM').format(DateTime.parse(plan['start_date'].toString()))}'
            ' - ${DateFormat('EEE d MMM').format(DateTime.parse(plan['end_date'].toString()))}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly meal plan',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeLabel,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _isGeneratingPlan ? null : _generateWeeklyPlan,
              icon: _isGeneratingPlan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(plan == null ? 'Generate' : 'Regenerate'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        planItems.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _emptyPanel(context, 'Unable to load your meal plan.'),
          data: (items) {
            if (items.isEmpty) {
              return _emptyPanel(
                context,
                'Your plan will appear here, one day at a time, with calories and macros for every meal.',
              );
            }
            final byDate = <String, List<Map<String, dynamic>>>{};
            for (final item in items) {
              final date = (item['plan_date'] ?? item['date']).toString();
              byDate.putIfAbsent(date, () => []).add(item);
            }
            final dates = byDate.keys.toList()..sort();
            final selected = dates.contains(_selectedDate)
                ? _selectedDate!
                : (dates.contains(today) ? today : dates.first);
            final dayItems = byDate[selected]!
              ..sort((a, b) => _slotOrder
                  .indexOf((a['meal_slot'] ?? '').toString())
                  .compareTo(_slotOrder.indexOf((b['meal_slot'] ?? '').toString())));
            final dayRecipes = dayItems.map(_recipeFromPlanItem).toList();
            double sum(double? Function(Recipe r) pick) =>
                dayRecipes.fold(0.0, (total, r) => total + (pick(r) ?? 0));
            final kcal = sum((r) => r.calories?.toDouble());

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: dates.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      return ChoiceChip(
                        label: Text(DateFormat('EEE d').format(DateTime.parse(date))),
                        selected: date == selected,
                        onSelected: (_) => setState(() => _selectedDate = date),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                GlassPanel(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target == null
                            ? '${kcal.round()} kcal planned'
                            : '${kcal.round()} / ${target.round()} kcal planned',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: target == null || target <= 0
                              ? 0
                              : (kcal / target).clamp(0.0, 1.0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Protein ${sum((r) => r.protein).round()}g   Carbs ${sum((r) => r.carbs).round()}g   Fat ${sum((r) => r.fat).round()}g',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < dayItems.length; i++)
                  _buildMealCard(
                    context,
                    dayItems[i],
                    dayRecipes[i],
                    eaten: selected == today &&
                        eatenKeys.contains('${dayRecipes[i].id}|${dayItems[i]['meal_slot']}'),
                    canLog: selected == today,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    Map<String, dynamic> item,
    Recipe recipe, {
    required bool eaten,
    required bool canLog,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final slot = (item['meal_slot'] ?? '').toString();
    final image = recipe.imageUrl;
    final macros = [
      if (recipe.calories != null) '${recipe.calories} kcal',
      if (recipe.protein != null) '${recipe.protein!.round()}g P',
      if (recipe.carbs != null) '${recipe.carbs!.round()}g C',
      if (recipe.fat != null) '${recipe.fat!.round()}g F',
    ].join('  ·  ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(context, '/recipeDetail', arguments: recipe),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: (image != null && image.isNotEmpty)
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.restaurant),
                        )
                      : Container(
                          color: colorScheme.primaryContainer,
                          child: const Icon(Icons.restaurant),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (macros.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(macros, style: textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (canLog)
                IconButton(
                  tooltip: eaten ? 'Logged' : 'Mark as eaten',
                  onPressed: eaten
                      ? null
                      : () => showLogMealSheet(context, ref, recipe, initialSlot: slot),
                  icon: Icon(
                    eaten ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: eaten ? colorScheme.primary : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroceriesTab(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> planItems,
    List<Ingredient> pantry,
    String dietType,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return planItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [_emptyPanel(context, 'Unable to load your grocery list.')],
      ),
      data: (items) {
        final generated = _buildShoppingItems(
          recipes: items.map(_recipeFromPlanItem).toList(),
          pantry: pantry,
          dietType: dietType,
        );
        final shoppingItems = _buildEffectiveShoppingItems(generated);
        final grouped = _groupItems(shoppingItems, _groupingMode);
        final bought =
            shoppingItems.where((i) => _checkedItems.contains(i.name.toLowerCase())).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            GlassPanel(
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shopping list',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items.isEmpty
                        ? 'Generate a meal plan to build your list.'
                        : 'Items from your plan that are not in your pantry.',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: shoppingItems.isEmpty ? 0 : bought / shoppingItems.length,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('$bought of ${shoppingItems.length} bought', style: textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showAddGroceryDialog(dietType),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                      OutlinedButton.icon(
                        onPressed: bought == 0 ? null : () => _saveCompletedShopping(shoppingItems),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Clear bought'),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isEditingGroceries = !_isEditingGroceries),
                        child: Text(_isEditingGroceries ? 'Done' : 'Edit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in grouped.entries)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    '${entry.key} (${entry.value.length})',
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  children: [
                    for (final item in entry.value)
                      _GroceryItemTile(
                        item: item,
                        editMode: _isEditingGroceries,
                        checked: _checkedItems.contains(item.name.toLowerCase()),
                        onRemove: () => _removeGroceryItem(item),
                        onToggle: () {
                          setState(() {
                            final key = item.name.toLowerCase();
                            if (!_checkedItems.remove(key)) _checkedItems.add(key);
                          });
                          _saveCheckedItems();
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
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

  Future<void> _generateWeeklyPlan() async {
    if (_isGeneratingPlan) return;
    setState(() {
      _isGeneratingPlan = true;
    });

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw StateError('Sign in to generate a plan.');
      final today = DateTime.now();
      final weekStart = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: today.weekday - 1));
      final result = await RecommendationService()
          .generateMealPlan(userId: userId, startDate: weekStart);
      if (result['plan_id'] == null) {
        throw StateError('The plan could not be saved. Please try again.');
      }
      ref.invalidate(activeMealPlanProvider);
      ref.invalidate(activeMealPlanItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['source'] == 'openai'
              ? 'AI meal plan generated for your profile.'
              : 'Meal plan generated.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, action: 'generate a meal plan'))),
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
