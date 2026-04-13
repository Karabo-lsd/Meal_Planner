import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final _tabs = ['Recommended', 'Quick Meals', 'Breakfast'];
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

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/pantry'),
            icon: const Icon(Icons.kitchen, color: Colors.black),
            tooltip: 'Pantry',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/dietaryProfile'),
            icon: const Icon(Icons.tune, color: Colors.black),
            tooltip: 'Dietary Profile',
          ),
        ],
        title: const Text(
          'Nutrition & Recipes',
          style: TextStyle(color: Color(0xFF1F2430)),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66C6B5FF), Color(0x00C6B5FF)],
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66B6E8FF), Color(0x00B6E8FF)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassPanel(
                  radius: 30,
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
                        color: Color(0xFF687487),
                      ),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF687487),
                              ),
                              onPressed: _resetSearch,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 36,
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
                          radius: 20,
                          color: isActive
                              ? const Color(0xAA2A3142)
                              : const Color(0x66FFFFFF),
                          borderColor: isActive
                              ? const Color(0xFF2A3142)
                              : const Color(0x80FFFFFF),
                          child: Text(
                            _tabs[index],
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF687487),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                const SizedBox(height: 16),
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
                    data: (recipes) => _buildRecipeGrid(recipes),
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

  Widget _buildRecipeGrid(List<Recipe> recipes) {
    final filtered = recipes.where((recipe) {
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

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3 / 4,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final recipe = filtered[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/recipeDetail', arguments: recipe);
          },
          child: GlassPanel(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEFF4FF), Color(0xFFFDF3EC)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fastfood,
                      size: 40,
                      color: Color(0xFF57637B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    recipe.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${recipe.calories ?? 0} kcal',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        recipe.prepTime != null
                            ? '${recipe.prepTime} min'
                            : '10 min',
                        style: const TextStyle(fontSize: 12),
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
}
