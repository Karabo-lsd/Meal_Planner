import 'package:flutter/material.dart';

import '../../shared/widgets/glass_panel.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Coach'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.2),
                    colorScheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary.withValues(alpha: 0.16),
                    colorScheme.secondary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildHeader(context),
                const SizedBox(height: 18),
                _buildSummaryCard(context),
                const SizedBox(height: 20),
                _buildActionTiles(context),
                const SizedBox(height: 20),
                _buildGoalOverview(context),
                const SizedBox(height: 20),
                _buildTipCard(context),
                const SizedBox(height: 20),
                _buildCoachingHighlights(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        GlassPanel(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Icon(
            Icons.support_agent_rounded,
            size: 28,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coach',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your nutrition guidance is ready. Let�s stay on track today.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today�s check-in',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You�re on track for your goals. Keep the momentum going.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(context, 'Hydration', '6/8 cups', colorScheme.primary),
              _buildMiniStat(
                context,
                'Protein',
                '68g',
                colorScheme.primary.withValues(alpha: 0.82),
              ),
              _buildMiniStat(
                context,
                'Energy',
                '75%',
                colorScheme.primary.withValues(alpha: 0.66),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTiles(BuildContext context) {
    return Row(
      children: [
        _buildActionTile(
          context,
          Icons.restaurant_menu,
          'Log meal',
          Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        _buildActionTile(
          context,
          Icons.auto_graph,
          'View plan',
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        ),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String label, Color color) {
    return Expanded(
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalOverview(BuildContext context) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Overview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _buildProgressRow(context, 'Calories', 0.85, '1,880 / 2,200 kcal'),
          const SizedBox(height: 14),
          _buildProgressRow(context, 'Protein', 0.72, '72 / 100 g'),
          const SizedBox(height: 14),
          _buildProgressRow(context, 'Water', 0.75, '6 / 8 cups'),
        ],
      ),
    );
  }

  Widget _buildProgressRow(BuildContext context, String label, double value, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            color: colorScheme.primary,
            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'Tip of the day',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Add one more serving of leafy greens at lunch to balance your fiber intake and support digestion.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingHighlights(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coaching Highlights',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 14),
        _buildHighlightRow(context, Icons.check_circle, 'Stay hydrated to support energy and recovery.'),
        const SizedBox(height: 12),
        _buildHighlightRow(context, Icons.restaurant, 'Choose a balanced snack with protein and fiber.'),
        const SizedBox(height: 12),
        _buildHighlightRow(context, Icons.stars, 'Keep your streak alive by logging today�s meals.'),
      ],
    );
  }

  Widget _buildHighlightRow(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
