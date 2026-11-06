import 'package:flutter/material.dart';
import '../../core/friendly_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/text_input.dart';

/// Collects the details needed to build a user's profile. Used as the
/// mandatory first-run screen; nothing is pre-filled except the signup name.
class OnboardingProfileSheet extends ConsumerStatefulWidget {
  const OnboardingProfileSheet({
    super.key,
    this.onSaved,
    this.onDismissed,
    this.onEditLater,
    this.mandatory = false,
  });

  final VoidCallback? onSaved;
  final VoidCallback? onDismissed;
  final VoidCallback? onEditLater;

  /// Hides the skip options so the profile must be completed.
  final bool mandatory;

  @override
  ConsumerState<OnboardingProfileSheet> createState() => _OnboardingProfileSheetState();
}

class _OnboardingProfileSheetState extends ConsumerState<OnboardingProfileSheet> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _excludedController = TextEditingController();
  final _proteinController = TextEditingController(text: '30');
  final _carbsController = TextEditingController(text: '40');
  final _fatController = TextEditingController(text: '30');

  String? _sex;
  String _goal = 'maintain_weight';
  String _diet = 'balanced';
  String _activity = 'moderate';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final name = ref.read(authStateProvider).user?.name?.trim();
    if (name != null && name.isNotEmpty) _nameController.text = name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _allergiesController.dispose();
    _excludedController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  List<String> _splitList(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  /// Mifflin-St Jeor BMR scaled by activity and adjusted for the goal.
  int _estimateCalories(int age, double height, double weight) {
    final base = 10 * weight + 6.25 * height - 5 * age;
    final bmr = switch (_sex) {
      'male' => base + 5,
      'female' => base - 161,
      _ => base - 78,
    };
    final factor = switch (_activity) {
      'light' => 1.375,
      'active' => 1.725,
      _ => 1.55,
    };
    final adjustment = switch (_goal) {
      'lose_weight' => -500,
      'gain_muscle' => 300,
      _ => 0,
    };
    return (bmr * factor + adjustment).round().clamp(1200, 5000);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final proteinRatio = double.tryParse(_proteinController.text.trim()) ?? 30;
    final carbRatio = double.tryParse(_carbsController.text.trim()) ?? 40;
    final fatRatio = double.tryParse(_fatController.text.trim()) ?? 30;

    if (name.isEmpty) return _toast('Please enter your name.');
    if (age == null || age < 5 || age > 120) return _toast('Enter a valid age (5-120).');
    if (_sex == null) return _toast('Please select your sex.');
    if (height == null || height < 50 || height > 260) {
      return _toast('Enter your height in centimetres.');
    }
    if (weight == null || weight < 20 || weight > 400) {
      return _toast('Enter your weight in kilograms.');
    }
    if ((proteinRatio + carbRatio + fatRatio - 100).abs() > 1) {
      return _toast('Protein, carbs and fat must add up to 100%.');
    }

    final enteredCalories = int.tryParse(_caloriesController.text.trim());
    final calories = enteredCalories != null && enteredCalories > 0
        ? enteredCalories
        : _estimateCalories(age, height, weight);

    final parts = name.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

    final data = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'age': age,
      'sex': _sex,
      'height': height,
      'weight': weight,
      'goal': _goal,
      'activity_level': _activity,
      'diet_type': _diet,
      'allergies': _splitList(_allergiesController.text),
      'excluded_ingredients': _splitList(_excludedController.text),
      'preferences': {'diet': _diet},
      'goals': {
        'daily_calories': calories,
        'protein_ratio': proteinRatio,
        'carb_ratio': carbRatio,
        'fat_ratio': fatRatio,
      },
    };

    setState(() => _saving = true);
    try {
      await ref.read(dietaryProfileProvider.notifier).updateProfile(data);
      await ref.read(authStateProvider.notifier).updateCurrentUserProfile({
        'first_name': firstName,
        'last_name': lastName,
      });
      if (!mounted) return;
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      _toast(friendlyErrorMessage(e, action: 'save your profile'));
    } finally {
      if (mounted) setState(() => _saving = false);
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
              Text(
                'Welcome! Let’s build your profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your details decide which meals we recommend. Allergies and excluded foods are never suggested.',
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
                          child: DropdownButtonFormField<String>(
                            initialValue: _sex,
                            decoration: const InputDecoration(labelText: 'Sex'),
                            items: const [
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (value) => setState(() => _sex = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextInput(
                            controller: _heightController,
                            label: 'Height (cm)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextInput(
                            controller: _weightController,
                            label: 'Weight (kg)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
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
                        DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
                        DropdownMenuItem(value: 'pescetarian', child: Text('Pescetarian')),
                        DropdownMenuItem(value: 'gluten_free', child: Text('Gluten free')),
                        DropdownMenuItem(value: 'keto', child: Text('Keto')),
                        DropdownMenuItem(value: 'paleo', child: Text('Paleo')),
                      ],
                      onChanged: (value) => setState(() => _diet = value ?? 'balanced'),
                    ),
                    const SizedBox(height: 12),
                    TextInput(
                      controller: _allergiesController,
                      label: 'Allergies (comma separated, e.g. peanut, shellfish)',
                    ),
                    const SizedBox(height: 12),
                    TextInput(
                      controller: _excludedController,
                      label: 'Foods to avoid (comma separated)',
                    ),
                    const SizedBox(height: 12),
                    TextInput(
                      controller: _caloriesController,
                      label: 'Daily kcal target (leave empty to calculate)',
                      keyboardType: TextInputType.number,
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
              PrimaryButton(
                label: 'Save profile',
                loading: _saving,
                onPressed: _save,
              ),
              if (!widget.mandatory) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    widget.onDismissed?.call();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Maybe later'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
