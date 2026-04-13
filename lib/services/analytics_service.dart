import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Daily summary ─────────────────────────────────────────

  Future<Map<String, dynamic>> getNutritionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final end = endDate ?? DateTime.now();

    final rows = await _supabase
        .from('food_logs')
        .select('log_date, calories, protein, carbs, fat')
        .eq('user_id', _userId)
        .gte('log_date', start.toIso8601String().split('T')[0])
        .lte('log_date', end.toIso8601String().split('T')[0]);

    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
    int count = 0;
    for (final r in rows) {
      totalCal += (r['calories'] as num?)?.toDouble() ?? 0;
      totalPro += (r['protein'] as num?)?.toDouble() ?? 0;
      totalCarb += (r['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (r['fat'] as num?)?.toDouble() ?? 0;
      count++;
    }

    return {
      'total_calories': totalCal,
      'total_protein': totalPro,
      'total_carbs': totalCarb,
      'total_fat': totalFat,
      'log_count': count,
      'avg_daily_calories': count > 0 ? totalCal / count : 0,
    };
  }

  Future<Map<String, dynamic>> getCalorieDistribution({DateTime? date}) async {
    final d = date ?? DateTime.now();
    final rows = await _supabase
        .from('food_logs')
        .select('meal_slot, calories')
        .eq('user_id', _userId)
        .eq('log_date', d.toIso8601String().split('T')[0]);

    final Map<String, double> bySlot = {};
    for (final r in rows) {
      final slot = r['meal_slot'] as String? ?? 'other';
      bySlot[slot] = (bySlot[slot] ?? 0) +
          ((r['calories'] as num?)?.toDouble() ?? 0);
    }
    return bySlot;
  }

  // ── Weekly / monthly aggregations ────────────────────────

  Future<Map<String, dynamic>> getMealFrequency({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final end = endDate ?? DateTime.now();

    final rows = await _supabase
        .from('food_logs')
        .select('meal_slot')
        .eq('user_id', _userId)
        .gte('log_date', start.toIso8601String().split('T')[0])
        .lte('log_date', end.toIso8601String().split('T')[0]);

    final Map<String, int> freq = {};
    for (final r in rows) {
      final slot = r['meal_slot'] as String? ?? 'other';
      freq[slot] = (freq[slot] ?? 0) + 1;
    }
    return freq;
  }

  Future<List<Map<String, dynamic>>> getWeeklyReport(
      {DateTime? weekStart}) async {
    final monday = weekStart ??
        DateTime.now()
            .subtract(Duration(days: DateTime.now().weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final rows = await _supabase
        .from('food_logs')
        .select('log_date, calories, protein, carbs, fat')
        .eq('user_id', _userId)
        .gte('log_date', monday.toIso8601String().split('T')[0])
        .lte('log_date', sunday.toIso8601String().split('T')[0])
        .order('log_date');

    final Map<String, Map<String, double>> byDate = {};
    for (final r in rows) {
      final d = r['log_date'] as String;
      byDate[d] ??= {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
      byDate[d]!['calories'] =
          byDate[d]!['calories']! + ((r['calories'] as num?)?.toDouble() ?? 0);
      byDate[d]!['protein'] =
          byDate[d]!['protein']! + ((r['protein'] as num?)?.toDouble() ?? 0);
      byDate[d]!['carbs'] =
          byDate[d]!['carbs']! + ((r['carbs'] as num?)?.toDouble() ?? 0);
      byDate[d]!['fat'] =
          byDate[d]!['fat']! + ((r['fat'] as num?)?.toDouble() ?? 0);
    }

    return byDate.entries
        .map((e) => {'date': e.key, ...e.value})
        .toList();
  }

  Future<Map<String, dynamic>> getMonthlyReport({DateTime? month}) async {
    final m = month ?? DateTime.now();
    final first = DateTime(m.year, m.month, 1);
    final last = DateTime(m.year, m.month + 1, 0);
    return (await getNutritionSummary(startDate: first, endDate: last))
      ..['month'] = '${m.year}-${m.month.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> getMacroBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      getNutritionSummary(startDate: startDate, endDate: endDate);

  Future<Map<String, dynamic>> getProgressTrends({
    String period = 'week',
    int periods = 4,
  }) async {
    final now = DateTime.now();
    final days = period == 'month' ? 30 : 7;
    return getNutritionSummary(
      startDate: now.subtract(Duration(days: days * periods)),
      endDate: now,
    );
  }

  Future<Map<String, dynamic>> getGoalProgress() async {
    final today = await getNutritionSummary(
        startDate: DateTime.now(), endDate: DateTime.now());
    final profile = await _supabase
        .from('user_profiles')
        .select(
            'daily_calorie_target, daily_protein_target, daily_carb_target, daily_fat_target')
        .eq('user_id', _userId)
        .maybeSingle();
    return {
      'consumed': today,
      'targets': profile ?? {},
    };
  }

  Future<List<Map<String, dynamic>>> getNutritionInsights(
      {int limit = 10}) async {
    final summary = await getNutritionSummary();
    return [
      {
        'type': 'avg_daily_calories',
        'value': summary['avg_daily_calories'],
        'label': 'Avg daily calories (7 days)',
      },
    ];
  }

}