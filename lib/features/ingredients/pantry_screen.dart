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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final ingredient = Ingredient(name: name, custom: true);
    ref.read(pantryProvider.notifier).addIngredient(ingredient);
    _nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66FFD8B9), Color(0x00FFD8B9)],
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
                          decoration: const InputDecoration(
                            hintText: 'Ingredient name',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF2A3142)),
                        onPressed: _addIngredient,
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
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
