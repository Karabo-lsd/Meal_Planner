import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _topics = <(String, String)>[
    (
      'How do I save a recipe?',
      'Open a recipe and tap its heart icon. You can find it later in Saved '
          'Recipes on your Profile.',
    ),
    (
      'How does food scanning work?',
      'Scan a food image to identify likely foods and estimate nutrition. '
          'Review the result before saving it to your food log.',
    ),
    (
      'How can I update my goals?',
      'Open Goal Setting from your Profile to update your dietary preferences '
          'and nutrition targets.',
    ),
    (
      'Where is my meal history?',
      'Meals you save are added to your nutrition tracking data and used to '
          'update your daily progress.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Quick answers for using Meal Planner.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Frequently asked questions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < _topics.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  ExpansionTile(
                    title: Text(_topics[index].$1),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(_topics[index].$2)],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('Contact support'),
              subtitle: const Text(
                'A support email address or help desk is not configured in '
                'this version of the app.',
              ),
              isThreeLine: true,
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.copyright_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('App icon credit'),
              subtitle: const Text(
                'Lunch icons created by Magnific - Flaticon',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
              onTap: () async {
                final opened = await launchUrl(
                  Uri.parse('https://www.flaticon.com/free-icons/lunch'),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the icon credit link.')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
