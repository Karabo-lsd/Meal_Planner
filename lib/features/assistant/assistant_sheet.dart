import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/providers.dart';
import '../../services/recommendation_service.dart';

class _ChatMessage {
  _ChatMessage({required this.fromUser, required this.text, this.recipes = const []});

  final bool fromUser;
  final String text;
  final List<Recipe> recipes;
}

/// Chat with the AI assistant. Answers are grounded in the user's Supabase
/// profile and recipes retrieved from Supabase/Spoonacular by the backend.
class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({super.key, required this.onPlanWeek});

  final VoidCallback onPlanWeek;

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    final userId = ref.read(currentUserIdProvider);
    if (text.isEmpty || _sending || userId == null) return;

    final history = _messages
        .map((m) => {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final result = await RecommendationService().chat(
        userId: userId,
        message: text,
        history: history,
      );
      final recipes = (result['recipes'] as List? ?? const [])
          .whereType<Map>()
          .map((m) {
            try {
              return Recipe.fromJson(Map<String, dynamic>.from(m));
            } catch (_) {
              return null;
            }
          })
          .whereType<Recipe>()
          .toList();
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
            fromUser: false,
            text: result['reply']?.toString() ?? '',
            recipes: recipes,
          )));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
            fromUser: false,
            text: 'I could not reach the assistant. Check your connection and try again.',
          )));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('AI Assistant',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    ? _buildIntro(colorScheme, textTheme)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _buildMessage(_messages[index], colorScheme);
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask for meals, swaps or nutrition advice',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _sending ? null : () => _send(_controller.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(ColorScheme colorScheme, TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: [
        Text(
          'Ask anything. Suggestions respect your diet, allergies and goals.',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(
              avatar: const Icon(Icons.restaurant_rounded, size: 18),
              label: const Text('Suggest dinner'),
              onPressed: () => _send('Suggest a dinner for me tonight'),
            ),
            ActionChip(
              avatar: const Icon(Icons.fitness_center_rounded, size: 18),
              label: const Text('High protein meals'),
              onPressed: () => _send('Suggest high protein meals that fit my goals'),
            ),
            ActionChip(
              avatar: const Icon(Icons.kitchen_rounded, size: 18),
              label: const Text('Cook from my pantry'),
              onPressed: () => _send('What can I cook with what is in my pantry?'),
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text('Plan my week'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onPlanWeek();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessage(_ChatMessage message, ColorScheme colorScheme) {
    final bubbleColor = message.fromUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    return Align(
      alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text),
            for (final recipe in message.recipes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(recipe.title),
                subtitle: recipe.calories == null
                    ? null
                    : Text('${recipe.calories} kcal'
                        '${recipe.protein == null ? '' : ' • ${recipe.protein!.round()}g protein'}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pushNamed('/recipeDetail', arguments: recipe);
                },
              ),
          ],
        ),
      ),
    );
  }
}
