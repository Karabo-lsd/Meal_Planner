import 'package:flutter/material.dart';
import '../../core/friendly_error.dart';
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
  final _allergiesController = TextEditingController();
  final _excludedIngredientsController = TextEditingController();
  String _diet = 'balanced';
  bool _initializedFromState = false;
  bool _saving = false;

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _allergiesController.dispose();
    _excludedIngredientsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final calories = int.tryParse(_caloriesController.text);
    final proteinRatio = double.tryParse(_proteinController.text);
    final carbsRatio = double.tryParse(_carbsController.text);
    final fatRatio = double.tryParse(_fatController.text);

    final proteinTarget = _macroTargetFromRatio(calories, proteinRatio, 4);
    final carbsTarget = _macroTargetFromRatio(calories, carbsRatio, 4);
    final fatTarget = _macroTargetFromRatio(calories, fatRatio, 9);

    final data = {
      'diet_type': _diet,
      'daily_calorie_target': calories,
      'daily_protein_target': proteinTarget,
      'daily_carb_target': carbsTarget,
      'daily_fat_target': fatTarget,
      'allergies': _splitList(_allergiesController.text),
      'excluded_ingredients': _splitList(_excludedIngredientsController.text),
      'preferences': {'diet': _diet},
      'goals': {
        'daily_calories': calories,
        'protein_ratio': proteinRatio,
        'carb_ratio': carbsRatio,
        'fat_ratio': fatRatio,
      },
    };

    setState(() => _saving = true);
    try {
      await ref.read(dietaryProfileProvider.notifier).updateProfile(data);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dietary profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, action: 'save your dietary profile'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(dietaryProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (!_initializedFromState && profile.isNotEmpty) {
      _caloriesController.text = _numberToText(
        profile['daily_calorie_target'] ?? profile['daily_calories'],
      );
      _proteinController.text = _numberToText(
        (profile['goals'] is Map)
            ? (profile['goals'] as Map)['protein_ratio']
            : null,
      );
      _carbsController.text = _numberToText(
        (profile['goals'] is Map)
            ? (profile['goals'] as Map)['carb_ratio']
            : null,
      );
      _fatController.text = _numberToText(
        (profile['goals'] is Map)
            ? (profile['goals'] as Map)['fat_ratio']
            : null,
      );
      _allergiesController.text = _listToText(profile['allergies']);
      _excludedIngredientsController.text = _listToText(
        profile['excluded_ingredients'],
      );

      final profileDiet = profile['diet_type']?.toString();
      final prefsDiet = (profile['preferences'] is Map)
          ? (profile['preferences'] as Map)['diet']?.toString()
          : null;
      _diet = (prefsDiet ?? profileDiet ?? _diet).toString();
      _initializedFromState = true;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.22),
                    colorScheme.primary.withValues(alpha: 0),
                  ],
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
                      decoration: _profileInputDecoration(
                        context,
                        'Diet preference',
                      ),
                      dropdownColor: colorScheme.surface,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
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
                      decoration: _profileInputDecoration(
                        context,
                        'Daily calories',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                      decoration: _profileInputDecoration(
                        context,
                        'Protein ratio (%)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                      decoration: _profileInputDecoration(
                        context,
                        'Carbs ratio (%)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fatController,
                      keyboardType: TextInputType.number,
                      decoration: _profileInputDecoration(
                        context,
                        'Fat ratio (%)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _allergiesController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _profileInputDecoration(
                        context,
                        'Allergies',
                      ).copyWith(helperText: 'Separate foods with commas'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _excludedIngredientsController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _profileInputDecoration(
                        context,
                        'Foods to avoid',
                      ).copyWith(helperText: 'Separate foods with commas'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _splitList(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  String _listToText(dynamic value) =>
      value is List ? value.map((item) => item.toString()).join(', ') : '';

  double? _macroTargetFromRatio(
    int? calories,
    double? ratioPercent,
    int caloriesPerGram,
  ) {
    if (calories == null || ratioPercent == null) return null;
    return (calories * (ratioPercent / 100.0)) / caloriesPerGram;
  }

  String _numberToText(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is double) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toStringAsFixed(1);
    }
    final parsed = double.tryParse(value.toString());
    if (parsed == null) return '';
    if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();
    return parsed.toStringAsFixed(1);
  }

  InputDecoration _profileInputDecoration(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.42),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
      ),
    );
  }
}
