import 'package:flutter/material.dart';

import '../../shared/widgets/glass_panel.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      appBar: AppBar(
        title: const Text('Training'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66FFD5C2), Color(0x00FFD5C2)],
                ),
              ),
            ),
          ),
          Center(
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              radius: 18,
              child: const Text('Training content here'),
            ),
          ),
        ],
      ),
    );
  }
}