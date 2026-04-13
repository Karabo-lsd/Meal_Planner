import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';

class DietaryProfileScreen extends ConsumerStatefulWidget {
  const DietaryProfileScreen({super.key});

  @override
  ConsumerState<DietaryProfileScreen> createState() =>
      _DietaryProfileScreenState();
}

class _DietaryProfileScreenState extends ConsumerState<DietaryProfileScreen> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _diet = 'balanced';

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final data = {
      'preferences': {'diet': _diet},
      'goals': {
        'daily_calories': int.tryParse(_caloriesController.text),
        'protein_ratio': double.tryParse(_proteinController.text),
        'carb_ratio': double.tryParse(_carbsController.text),
        'fat_ratio': double.tryParse(_fatController.text),
      },
    };

    await ref.read(dietaryProfileProvider.notifier).updateProfile(data);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dietary profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      appBar: AppBar(
        title: const Text('Dietary Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -110,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66B9C7FF), Color(0x00B9C7FF)],
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(16),
                radius: 20,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _diet,
                      decoration: const InputDecoration(
                    labelText: 'Diet preference',
                  ),
                      items: const [
                        DropdownMenuItem(
                      value: 'balanced',
                      child: Text('Balanced'),
                    ),
                        DropdownMenuItem(value: 'keto', child: Text('Keto')),
                        DropdownMenuItem(
                      value: 'high_protein',
                      child: Text('High Protein'),
                    ),
                        DropdownMenuItem(
                      value: 'vegetarian',
                      child: Text('Vegetarian'),
                    ),
                      ],
                      onChanged: (v) => setState(() => _diet = v ?? 'balanced'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                    labelText: 'Daily calories',
                  ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                    labelText: 'Protein ratio (%)',
                  ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                    labelText: 'Carbs ratio (%)',
                  ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fat ratio (%)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A3142),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
