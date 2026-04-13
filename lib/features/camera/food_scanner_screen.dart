import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/food_scan_result.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';

class FoodScannerScreen extends ConsumerStatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  ConsumerState<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends ConsumerState<FoodScannerScreen> {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (_isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      String? imagePath;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final picture = await _cameraController!.takePicture();
        imagePath = picture.path;
      } else {
        final picker = ImagePicker();
        final fallback = await picker.pickImage(source: ImageSource.camera);
        imagePath = fallback?.path;
      }

      if (imagePath == null || !mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FoodScanResultScreen(imagePath: imagePath!),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : (_cameraController != null && _cameraController!.value.isInitialized)
            ? CameraPreview(_cameraController!)
            : Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Text(
                  'Camera unavailable',
                  style: TextStyle(color: Colors.white),
                ),
              );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.45),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleIcon(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'AI Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _circleIcon(
                    icon: Icons.more_horiz,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              children: [
                Container(
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    radius: 20,
                    color: const Color(0x55333333),
                    borderColor: const Color(0x66FFFFFF),
                    child: const Text(
                      'AI Camera / Scan Food',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _captureAndAnalyze,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xAAFFFFFF),
                      border: Border.all(color: const Color(0xCCFFFFFF), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isCapturing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.black, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: GlassPanel(
        width: 40,
        height: 40,
        radius: 22,
        color: const Color(0x55333333),
        borderColor: const Color(0x66FFFFFF),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class FoodScanResultScreen extends ConsumerStatefulWidget {
  const FoodScanResultScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<FoodScanResultScreen> createState() => _FoodScanResultScreenState();
}

class _FoodScanResultScreenState extends ConsumerState<FoodScanResultScreen> {
  FoodScanResult? _result;
  bool _loading = true;
  int _servings = 1;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final scan = await ref.read(foodScanServiceProvider).analyzeMealImage(widget.imagePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = scan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = const FoodScanResult(
          mealTitle: 'Scanned Meal',
          mealType: 'Meal',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          confidence: 0,
          raw: {},
        );
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI analysis failed: $e')),
      );
    }
  }

  Future<void> _editValue(String key, num current) async {
    final controller = TextEditingController(text: current.toString());
    final updated = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $key'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'Enter $key value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = num.tryParse(controller.text.trim());
              Navigator.pop(context, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == null || _result == null) {
      return;
    }

    setState(() {
      switch (key) {
        case 'Calories':
          _result = _result!.copyWith(calories: updated.round());
          break;
        case 'Protein':
          _result = _result!.copyWith(protein: updated.toDouble());
          break;
        case 'Carbs':
          _result = _result!.copyWith(carbs: updated.toDouble());
          break;
        case 'Fat':
          _result = _result!.copyWith(fat: updated.toDouble());
          break;
      }
    });
  }

  Future<void> _done() async {
    if (_result == null) {
      Navigator.pop(context);
      return;
    }

    try {
      await ref.read(mealServiceProvider).logMeal(
            mealType: _result!.mealType,
            manualEntry: _result!.confidence < 0.5,
            analysisResult: {
              ..._result!.toJson(),
              'servings': _servings,
            },
          );
    } catch (_) {
      // Keep UX smooth even if backend log fails.
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _resultTopIcon(context, Icons.close, () => Navigator.pop(context)),
                  _resultTopIcon(context, Icons.more_horiz, () {}),
                ],
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            DraggableScrollableSheet(
              initialChildSize: 0.48,
              minChildSize: 0.45,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    children: [
                      GlassPanel(
                        radius: 26,
                        color: const Color(0xDDF7F7F8),
                        borderColor: const Color(0x99FFFFFF),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            result?.mealType ?? 'Meal',
                            style: const TextStyle(
                              color: Color(0xFF8FA4FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GlassPanel(
                            radius: 18,
                            color: const Color(0x88FFFFFF),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: _servings > 1
                                      ? () => setState(() => _servings -= 1)
                                      : null,
                                  child: const Icon(Icons.remove, size: 18),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('$_servings'),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _servings += 1),
                                  child: const Icon(Icons.add, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result?.mealTitle ?? 'Scanned Meal',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if ((result?.confidence ?? 1) < 0.7)
                        const Text(
                          'AI confidence is low. You can edit nutrition values manually.',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                        ),
                      const SizedBox(height: 14),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _macroCard(
                            label: 'Calories',
                            value: '${result?.calories ?? 0}',
                            icon: Icons.local_fire_department,
                            color: const Color(0xFFFFC446),
                            onEdit: () => _editValue('Calories', result?.calories ?? 0),
                          ),
                          _macroCard(
                            label: 'Protein',
                            value: '${(result?.protein ?? 0).toStringAsFixed(0)}gm',
                            icon: Icons.science,
                            color: const Color(0xFF4CB2FF),
                            onEdit: () => _editValue('Protein', result?.protein ?? 0),
                          ),
                          _macroCard(
                            label: 'Carbs',
                            value: '${(result?.carbs ?? 0).toStringAsFixed(0)}gm',
                            icon: Icons.spa,
                            color: const Color(0xFF8F5DFF),
                            onEdit: () => _editValue('Carbs', result?.carbs ?? 0),
                          ),
                          _macroCard(
                            label: 'Fat',
                            value: '${(result?.fat ?? 0).toStringAsFixed(0)}gm',
                            icon: Icons.opacity,
                            color: const Color(0xFF7CCB6D),
                            onEdit: () => _editValue('Fat', result?.fat ?? 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF161B24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: _done,
                          child: const Text(
                            'Done',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _macroCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onEdit,
  }) {
    return GlassPanel(
      radius: 14,
      color: const Color(0xAAFFFFFF),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                child: const Text('Edit'),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _resultTopIcon(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: GlassPanel(
        width: 40,
        height: 40,
        radius: 22,
        color: const Color(0x55333333),
        borderColor: const Color(0x66FFFFFF),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
