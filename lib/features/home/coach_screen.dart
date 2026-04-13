import 'package:flutter/material.dart';

import '../../shared/widgets/glass_panel.dart';

class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFFC),
      appBar: AppBar(
        title: const Text('Coach'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -110,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0x66BCEBD7), Color(0x00BCEBD7)],
                ),
              ),
            ),
          ),
          Center(
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              radius: 18,
              child: const Text('Coach content here'),
            ),
          ),
        ],
      ),
    );
  }
}