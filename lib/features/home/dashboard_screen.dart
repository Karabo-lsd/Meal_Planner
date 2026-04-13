import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const List<_CategoryItem> _categories = [
    _CategoryItem(label: 'Vegan', icon: Icons.eco),
    _CategoryItem(label: 'Protein', icon: Icons.fitness_center),
    _CategoryItem(label: 'Low Carb', icon: Icons.grain),
    _CategoryItem(label: 'Snacks', icon: Icons.lunch_dining),
    _CategoryItem(label: 'Drinks', icon: Icons.local_drink),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final recommendationsAsync = ref.watch(recommendationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0x66B9C7FF), Color(0x00B9C7FF)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0x66FFD8B9), Color(0x00FFD8B9)],
                  ),
                ),
              ),
            ),
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                _buildHeader(context, user?.name ?? 'User'),
                const SizedBox(height: 20),
                Text(
                  'What are you craving\ntoday, buddy?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSearchBar(context),
                const SizedBox(height: 24),
                _buildCategories(context),
                const SizedBox(height: 24),
                _buildSmartMealPicksSection(context, recommendationsAsync),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartMealPicksSection(
    BuildContext context,
    AsyncValue<List<Recipe>> recommendationsAsync,
  ) {
    return recommendationsAsync.when(
      data: (recipes) =>
          _buildSmartMealPicks(context, _applyHomeFilters(recipes)),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Meal Picks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Meal Picks',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _glassPanel(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Unable to load meal picks right now.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFDCE3FF),
            child: Text(
              userName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF2A3142),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Good Morning.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7D8799),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No new notifications')),
            );
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _glassPanel(
                  radius: 20,
                  width: 40,
                  height: 40,
                  child: const SizedBox.shrink(),
                ),
                const Icon(Icons.notifications_none, color: Color(0xFF2A3142)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _glassPanel(
            radius: 28,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'What are you craving today?',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA0A7B5),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF636E7F)),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF636E7F)),
                        onPressed: _resetSearch,
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: _resetFilters,
          child: _glassPanel(
            width: 46,
            height: 46,
            radius: 23,
            color: const Color(0x88F0E9FF),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF6A4BCE),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Browse by Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _categories[index];
              final selected = _selectedCategory == item.label;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = selected ? 'All' : item.label;
                  });
                },
                child: Column(
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: _glassPanel(
                        radius: 18,
                        color: selected
                            ? const Color(0x88EAF1FF)
                            : const Color(0x66FFFFFF),
                        borderColor: selected
                            ? const Color(0xFF4D74FF)
                            : const Color(0x66FFFFFF),
                        child: Icon(item.icon, color: const Color(0xFF2D3748)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF636E7F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSmartMealPicks(BuildContext context, List<Recipe> recipes) {
    final picks = recipes.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Smart Meal Picks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (_hasActiveFilters)
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Reset'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (recipes.isEmpty)
          _glassPanel(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No meal picks yet. Try adjusting search or categories.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: picks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final recipe = picks[index];
                final isFavorite = ref
                    .watch(savedRecipeIdsProvider)
                    .contains(recipe.id);
                return GestureDetector(
                  onTap: () => _openDetail(context, recipe),
                  child: _glassPanel(
                    width: 210,
                    radius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFEFF4FF), Color(0xFFF9F0EA)],
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  _resolveRecipeImage(recipe),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.restaurant,
                                      size: 56,
                                      color: Color(0xFF53627D),
                                    ),
                                  ),
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xA6000000),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      recipe.prepTime != null
                                          ? '${recipe.prepTime} min'
                                          : 'Quick',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recipe.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _toggleFavorite(recipe),
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.redAccent
                                      : const Color(0xFF9AA3B4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _glassPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            color: const Color(0x66F1F5FF),
                            radius: 14,
                            child: Text(
                              '${recipe.calories ?? 0} kcal',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3B4A62),
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (recipes.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Recommendations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) =>
                _buildGridRecipeCard(context, recipes[index]),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildGridRecipeCard(BuildContext context, Recipe recipe) {
    final isFavorite = ref.watch(savedRecipeIdsProvider).contains(recipe.id);
    return GestureDetector(
      onTap: () => _openDetail(context, recipe),
      child: _glassPanel(
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 122,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _resolveRecipeImage(recipe),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFEFF4FF),
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 42,
                          color: Color(0xFF53627D),
                        ),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const ColoredBox(
                        color: Color(0xFFEFF4FF),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xA6000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        recipe.prepTime != null
                            ? '${recipe.prepTime} min'
                            : 'Quick',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _glassPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            color: const Color(0x66F1F5FF),
                            radius: 10,
                            child: Text(
                              '${recipe.calories ?? 0} kcal',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF3B4A62),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () => _toggleFavorite(recipe),
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: isFavorite
                                  ? Colors.redAccent
                                  : const Color(0xFF9AA3B4),
                            ),
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

  void _openDetail(BuildContext context, Recipe recipe) {
    Navigator.pushNamed(
      context,
      '/recipeDetail',
      arguments: recipe.copyWithImageUrl(_resolveRecipeImage(recipe)),
    );
  }

  List<Recipe> _applyHomeFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final title = recipe.title.toLowerCase();
      final description = (recipe.description ?? '').toLowerCase();
      final ingredients = (recipe.ingredients ?? const [])
          .map((e) => e.toLowerCase())
          .toList();

      final queryOk =
          _searchQuery.isEmpty ||
          title.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          ingredients.any((e) => e.contains(_searchQuery));

      final categoryOk =
          _selectedCategory == 'All' ||
          _matchesCategory(recipe, _selectedCategory);
      return queryOk && categoryOk;
    }).toList();
  }

  bool _matchesCategory(Recipe recipe, String category) {
    final tags = (recipe.tags ?? const []).map(_normalize).toSet();
    final diets = (recipe.supportedDiets ?? const []).map(_normalize).toSet();
    final title = _normalize(recipe.title);
    final description = _normalize(recipe.description ?? '');

    bool hasAny(Iterable<String> candidates) => candidates.any(
      (c) => tags.contains(_normalize(c)) || diets.contains(_normalize(c)),
    );

    switch (category) {
      case 'Vegan':
        return hasAny(const ['vegan', 'plant based']) ||
            title.contains('vegan');
      case 'Protein':
        return hasAny(const ['high protein', 'protein']) ||
            title.contains('protein') ||
            description.contains('protein');
      case 'Low Carb':
        return hasAny(const ['low carb', 'keto', 'ketogenic']) ||
            title.contains('low carb') ||
            title.contains('keto');
      case 'Snacks':
        return hasAny(const ['snack', 'snacks']) || title.contains('snack');
      case 'Drinks':
        return hasAny(const ['drink', 'drinks', 'beverage', 'smoothie']) ||
            title.contains('drink') ||
            title.contains('smoothie');
      default:
        return true;
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedCategory != 'All';

  String _resolveRecipeImage(Recipe recipe) {
    final fromDb = recipe.imageUrl?.trim();
    if (fromDb != null && fromDb.isNotEmpty) {
      return fromDb;
    }
    final lock = recipe.id.hashCode.abs();
    return 'https://loremflickr.com/640/480/food?lock=$lock';
  }

  void _resetSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = 'All';
    });
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ').trim();
  }

  void _toggleFavorite(Recipe recipe) {
    ref.read(savedRecipeIdsProvider.notifier).toggle(recipe.id);
  }

  Widget _glassPanel({
    required Widget child,
    double radius = 20,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
    Color color = const Color(0x66FFFFFF),
    Color borderColor = const Color(0x80FFFFFF),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
