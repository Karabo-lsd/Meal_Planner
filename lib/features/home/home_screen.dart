import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_screen_premium.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DashboardScreen();
  }
}
/*
      Widget _buildNutritionStatsSection(BuildContext context) {
    final chartData = _getChartData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calorie Intake',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Row(
              children: [
                _buildToggleButton('Day', _selectedPeriod == 'Day', () {
                  setState(() {
                    _selectedPeriod = 'Day';
                  });
                }),
                _buildToggleButton('Week', _selectedPeriod == 'Week', () {
                  setState(() {
                    _selectedPeriod = 'Week';
                  });
                }),
                _buildToggleButton('Month', _selectedPeriod == 'Month', () {
                  setState(() {
                    _selectedPeriod = 'Month';
                  });
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Consumed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${chartData['consumed']} kcal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Sample line chart (simplified visualization)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      chartData['bars'].length,
                      (index) => GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Day ${index + 1}: ${(chartData['bars'][index] * 2500).toStringAsFixed(0)} kcal',
                              ),
                              duration: const Duration(milliseconds: 500),
                            ),
                          );
                        },
                        child: _buildChartBar(chartData['bars'][index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getChartData() {
    switch (_selectedPeriod) {
      case 'Week':
        return {
          'consumed': '2343',
          'bars': [0.4, 0.6, 0.8, 0.7, 0.9, 0.5, 0.75],
        };
      case 'Month':
        return {
          'consumed': '2400',
          'bars': [0.5, 0.6, 0.7, 0.65, 0.8, 0.75, 0.85],
        };
      case 'Day':
      default:
        return {
          'consumed': '1850',
          'bars': [0.6, 0.7, 0.5, 0.8, 0.65, 0.9, 0.75],
        };
    }
  }

  Widget _buildChartBar(double heightFactor) {
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Container(
        height: 100 * heightFactor,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary
              : colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMealStatusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meals This Week',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Monday', 2200),
                    child: _buildMealStatItem('Monday', 2200),
                  ),
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Tuesday', 2100),
                    child: _buildMealStatItem('Tuesday', 2100),
                  ),
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Wednesday', 2350),
                    child: _buildMealStatItem('Wednesday', 2350),
                  ),
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Thursday', 2450),
                    child: _buildMealStatItem('Thursday', 2450),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Friday', 2300),
                    child: _buildMealStatItem('Friday', 2300),
                  ),
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Saturday', 2600),
                    child: _buildMealStatItem('Saturday', 2600),
                  ),
                  GestureDetector(
                    onTap: () => _showDayDetails(context, 'Sunday', 2400),
                    child: _buildMealStatItem('Sunday', 2400),
                  ),
                  Column(
                    children: [
                      Text(
                        'Avg',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2343',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDayDetails(BuildContext context, String day, int calories) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$day: $calories kcal consumed'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildMealStatItem(String day, int calories) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Container(
          width: 50,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                primary,
                primary.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day.substring(0, 3),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '$calories',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildGoalsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Goals',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showGoalDetails(context, 'Daily Calorie Goal', 1850, 2500),
          child: _buildGoalItem(
            context,
            'Daily Calorie Goal',
            2500,
            1850,
            Colors.orange[400] ?? Colors.orange,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showGoalDetails(context, 'Protein Intake', 85, 100),
          child: _buildGoalItem(
            context,
            'Protein Intake',
            100,
            85,
            Colors.blue[400] ?? Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showGoalDetails(context, 'Water Intake', 5.5, 8),
          child: _buildGoalItem(
            context,
            'Water Intake',
            8,
            5.5,
            Colors.cyan[400] ?? Colors.cyan,
          ),
        ),
      ],
    );
  }

  void _showGoalDetails(BuildContext context, String goal, num current, num target) {
    final progress = ((current / target) * 100).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$goal: $current/$target ($progress%)'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildGoalItem(
    BuildContext context,
    String label,
    num goal,
    num current,
    Color color,
  ) {
    final progress = current / goal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $goal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              Text(
                label.contains('Water')
                    ? 'cups / day'
                    : label.contains('Protein')
                        ? 'g / day'
                        : 'kcal / day',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
*/
