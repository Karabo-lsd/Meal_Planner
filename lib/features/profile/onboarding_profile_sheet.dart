import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/text_input.dart';

class OnboardingProfileSheet extends ConsumerStatefulWidget {
  const OnboardingProfileSheet({
    super.key,
    this.onSaved,
    this.onDismissed,
    this.onEditLater,
  });

  final VoidCallback? onSaved;
  final VoidCallback? onDismissed;
  final VoidCallback? onEditLater;

  @override
  ConsumerState<OnboardingProfileSheet> createState() => _OnboardingProfileSheetState();
}

class _OnboardingProfileSheetState extends ConsumerState<OnboardingProfileSheet> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController(text: '30');
  final _carbsController = TextEditingController(text: '40');
  final _fatController = TextEditingController(text: '30');

  String _goal = 'maintain_weight';
  String _diet = 'balanced';
  String _activity = 'moderate';

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text);
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    final calories = int.tryParse(_caloriesController.text);
    final proteinRatio = double.tryParse(_proteinController.text);
    final carbRatio = double.tryParse(_carbsController.text);
    final fatRatio = double.tryParse(_fatController.text);

    if (name.isEmpty || age == null || height == null || weight == null || calories == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required fields.')),
      );
      return;
    }

    final data = {
      'first_name': name,
      'age': age,
      'height': height,
      'weight': weight,
      'goal': _goal,
      'activity_level': _activity,
      'daily_calorie_target': calories,
      'daily_protein_target': proteinRatio ?? 30,
      'daily_carb_target': carbRatio ?? 40,
      'daily_fat_target': fatRatio ?? 30,
      'diet_type': _diet,
      'preferences': {
        'diet': _diet,
      },
      'goals': {
        'daily_calories': calories,
        'protein_ratio': proteinRatio ?? 30,
        'carb_ratio': carbRatio ?? 40,
        'fat_ratio': fatRatio ?? 30,
      },
    };

    try {
      await ref.read(dietaryProfileProvider.notifier).updateProfile(data);
      await ref.read(authStateProvider.notifier).updateCurrentUserProfile({
        'first_name': name,
        'last_name': null,
      });
      if (!mounted) return;
      widget.onSaved?.call();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save your profile right now: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Welcome! Let’s personalize your plan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'A few details help us recommend meals that fit your goals and preferences.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(18),
                radius: 24,
                child: Column(
                  children: [
                    TextInput(controller: _nameController, label: 'Your name'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextInput(
                            controller: _ageController,
                            label: 'Age',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextInput(
                            controller: _heightController,
                            label: 'Height (cm)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextInput(
                            controller: _weightController,
                            label: 'Weight (kg)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextInput(
                            controller: _caloriesController,
                            label: 'Target kcal',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _goal,
                      decoration: const InputDecoration(labelText: 'Primary goal'),
                      items: const [
                        DropdownMenuItem(value: 'lose_weight', child: Text('Lose weight')),
                        DropdownMenuItem(value: 'maintain_weight', child: Text('Maintain weight')),
                        DropdownMenuItem(value: 'gain_muscle', child: Text('Gain muscle')),
                      ],
                      onChanged: (value) => setState(() => _goal = value ?? 'maintain_weight'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _diet,
                      decoration: const InputDecoration(labelText: 'Diet style'),
                      items: const [
                        DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
                        DropdownMenuItem(value: 'high_protein', child: Text('High protein')),
                        DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarian')),
                        DropdownMenuItem(value: 'keto', child: Text('Keto')),
                      ],
                      onChanged: (value) => setState(() => _diet = value ?? 'balanced'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _activity,
                      decoration: const InputDecoration(labelText: 'Activity level'),
                      items: const [
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                      ],
                      onChanged: (value) => setState(() => _activity = value ?? 'moderate'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextInput(
                            controller: _proteinController,
                            label: 'Protein %',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextInput(
                            controller: _carbsController,
                            label: 'Carbs %',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextInput(
                            controller: _fatController,
                            label: 'Fat %',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onDismissed?.call();
                        Navigator.of(context).maybePop();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Maybe later'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save profile',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  widget.onEditLater?.call();
                  Navigator.of(context).maybePop();
                },
                child: const Text('Edit later in settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
