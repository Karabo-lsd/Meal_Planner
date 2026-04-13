import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../services/session_storage.dart';
import 'dashboard_screen.dart';
import '../recipes/nutrition_screen.dart';
import 'coach_screen.dart';
import 'training_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    DashboardScreen(),
    NutritionScreen(),
    SizedBox.shrink(), // unused placeholder for add button
    CoachScreen(),
    TrainingScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Restore last active tab for this user.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final saved = SessionStorage.loadTab(userId);
      // Avoid tab 2 (the add button — it has no page).
      if (saved != 2) _currentIndex = saved;
    }
    // Warm up providers once user lands here so home recommendations render fast.
    Future.microtask(() {
      ref.read(pantryProvider);
      ref.read(dietaryProfileProvider);
      ref.read(savedRecipeIdsProvider);
      ref.read(recommendationsProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0x66FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x80FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              backgroundColor: const Color(0x44FFFFFF),
              selectedItemColor: const Color(0xFF2A3142),
              unselectedItemColor: const Color(0xFF9AA3B4),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              onTap: (i) {
                if (i == 2) {
                  _showAddMenu();
                  return;
                }
                setState(() => _currentIndex = i);
                // Persist so the same tab re-opens on next launch.
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId != null) SessionStorage.saveTab(userId, i);
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Nutrition'),
                BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40), label: ''),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Coach'),
                BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'Training'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.fastfood),
                  title: const Text('Scan Food (AI)'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/foodScanner');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_drink),
                  title: const Text('Log Water'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.kitchen),
                  title: const Text('Manage Pantry'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/pantry');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Update Dietary Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/dietaryProfile');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}