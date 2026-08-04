import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ingredient.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;

    final ingredient = Ingredient(name: name, custom: true);
    setState(() => _isSaving = true);

    try {
      await ref.read(pantryProvider.notifier).addIngredient(ingredient);
      _nameController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $name to pantry')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save ingredient: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Pantry'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.18),
                    colorScheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(8),
                  radius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addIngredient(),
                          decoration: const InputDecoration(
                            hintText: 'Ingredient name',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: colorScheme.primary),
                        onPressed: _isSaving ? null : _addIngredient,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: pantry.length,
                    itemBuilder: (context, index) {
                      final ing = pantry[index];
                      return GlassPanel(
                        margin: const EdgeInsets.only(bottom: 10),
                        radius: 14,
                        child: ListTile(
                          title: Text(ing.name),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.primary,
                            ),
                            onPressed: () =>
                                ref.read(pantryProvider.notifier).removeIngredient(ing),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
