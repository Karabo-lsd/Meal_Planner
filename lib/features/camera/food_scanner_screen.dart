import 'dart:io';
import '../../core/friendly_error.dart';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/food_scan_result.dart';
import '../../core/providers.dart';
import '../../shared/widgets/glass_panel.dart';

class FoodScannerScreen extends ConsumerStatefulWidget {
  const FoodScannerScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends ConsumerState<FoodScannerScreen> {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isCapturing = false;
  static const Color _accentColor = Color(0xFF67D8FF);

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
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

      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
      if (!mounted) {
        await controller.dispose();
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
      await _openResult(imagePath);
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickFromGalleryAndAnalyze() async {
    if (_isCapturing) {
      return;
    }

    final picker = ImagePicker();
    final selected = await picker.pickImage(source: ImageSource.gallery);
    final imagePath = selected?.path;
    if (imagePath == null || !mounted) {
      return;
    }
    await _openResult(imagePath);
  }

  Future<void> _openResult(String imagePath) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodScanResultScreen(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
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

    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveScanner();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            const _ScannerBackdrop(),
            _buildTopBar(),
            LayoutBuilder(
              builder: (context, constraints) {
                final safeHeight =
                    constraints.maxHeight -
                    MediaQuery.paddingOf(context).vertical;
                final maxFrameSize = math.max(150.0, safeHeight * 0.44);
                final frameSize = (screenSize.shortestSide * 0.64).clamp(
                  150.0,
                  maxFrameSize,
                );
                return Center(child: _buildScanFrame(frameSize));
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: _buildBottomDock(),
            ),
          ],
        ),
      ),
    );
  }

  void _leaveScanner() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Row(
          children: [
            _circleIcon(icon: Icons.arrow_back_ios_new, onTap: _leaveScanner),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Align your meal inside the frame',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GlassPanel(
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: const Color(0x4D0B111A),
              borderColor: const Color(0x99A9E7FF),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: _accentColor),
                  SizedBox(width: 6),
                  Text(
                    'AI Live',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanFrame(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
        SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: const [
                _FrameCorner(alignment: Alignment.topLeft),
                _FrameCorner(alignment: Alignment.topRight),
                _FrameCorner(alignment: Alignment.bottomLeft),
                _FrameCorner(alignment: Alignment.bottomRight),
              ],
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_rounded,
              size: 34,
              color: Colors.white.withValues(alpha: 0.78),
            ),
            const SizedBox(height: 8),
            Text(
              'Place your meal here',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomDock() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: GlassPanel(
          radius: 28,
          color: const Color(0xCC0B111A),
          borderColor: const Color(0x66E4F7FF),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Good lighting helps identify your meal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _secondaryAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: _pickFromGalleryAndAnalyze,
                  ),
                  GestureDetector(
                    onTap: _captureAndAnalyze,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xE9FFFFFF),
                        border: Border.all(
                          color: const Color(0xFFEAFBFF),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.42),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
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
                          : Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0F141C),
                                  width: 2,
                                ),
                              ),
                            ),
                    ),
                  ),
                  _secondaryAction(
                    icon: Icons.tips_and_updates_outlined,
                    label: 'Tips',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Use even lighting and keep the camera steady.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: GlassPanel(
        width: 44,
        height: 44,
        radius: 22,
        color: const Color(0x66060A12),
        borderColor: const Color(0x66D5F5FF),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ScannerBackdrop extends StatelessWidget {
  const _ScannerBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.58),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.2),
          Colors.black.withValues(alpha: 0.78),
        ],
        stops: const [0, 0.32, 0.64, 1],
      ),
    ),
  );
}

class _FrameCorner extends StatelessWidget {
  const _FrameCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _CornerPainter(isTop: isTop, isLeft: isLeft),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _FoodScannerScreenState._accentColor
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final horizontalStart = Offset(
      isLeft ? 0 : size.width,
      isTop ? 0 : size.height,
    );
    final horizontalEnd = Offset(
      isLeft ? 26 : size.width - 26,
      isTop ? 0 : size.height,
    );
    final verticalEnd = Offset(
      isLeft ? 0 : size.width,
      isTop ? 26 : size.height - 26,
    );

    path.moveTo(horizontalStart.dx, horizontalStart.dy);
    path.lineTo(horizontalEnd.dx, horizontalEnd.dy);
    path.moveTo(horizontalStart.dx, horizontalStart.dy);
    path.lineTo(verticalEnd.dx, verticalEnd.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FoodScanResultScreen extends ConsumerStatefulWidget {
  const FoodScanResultScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<FoodScanResultScreen> createState() =>
      _FoodScanResultScreenState();
}

class _FoodScanResultScreenState extends ConsumerState<FoodScanResultScreen> {
  FoodScanResult? _result;
  bool _loading = true;
  bool _saving = false;
  int _servings = 1;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final scan = await ref
          .read(foodScanServiceProvider)
          .analyzeMealImage(widget.imagePath);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, action: 'analyze this image'))),
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
          _result = _result!.copyWith(calories: (updated / _servings).round());
          break;
        case 'Protein':
          _result = _result!.copyWith(protein: updated.toDouble() / _servings);
          break;
        case 'Carbs':
          _result = _result!.copyWith(carbs: updated.toDouble() / _servings);
          break;
        case 'Fat':
          _result = _result!.copyWith(fat: updated.toDouble() / _servings);
          break;
      }
    });
  }

  Future<void> _done() async {
    if (_result == null) {
      Navigator.pop(context);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = _result!;
      await ref
          .read(mealServiceProvider)
          .logMeal(
            mealType: result.mealType,
            manualEntry: result.confidence < 0.5,
            analysisResult: {
              ...result.toJson(),
              'foods': result.raw['foods'],
              'calories': result.calories * _servings,
              'protein': result.protein * _servings,
              'carbs': result.carbs * _servings,
              'fat': result.fat * _servings,
              'servings': _servings,
            },
          );
      ref.invalidate(todayLogsProvider);
      ref.invalidate(goalProgressProvider);
      ref.invalidate(nutritionSummaryProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final errorText = error.toString().toLowerCase();
      final message =
          errorText.contains('food_name') ||
              errorText.contains('usda_fdc_id') ||
              errorText.contains('food_logs_food_or_recipe_chk')
          ? 'We could not save this meal right now. Please try again later.'
          : friendlyErrorMessage(error, action: 'save this meal');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final recognizedFoods = result?.raw['foods'];
    final foods = recognizedFoods is List
        ? recognizedFoods.whereType<Map>().toList(growable: false)
        : const <Map>[];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _resultTopIcon(
                    context,
                    Icons.close,
                    () => Navigator.pop(context),
                  ),
                  _resultTopIcon(context, Icons.more_horiz, () {}),
                ],
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            DraggableScrollableSheet(
              initialChildSize: 0.48,
              minChildSize: 0.45,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
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
                                  color: const Color(0xEEFFFFFF),
                                  borderColor: const Color(0x33161B24),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: _servings > 1
                                            ? () =>
                                                  setState(() => _servings -= 1)
                                            : null,
                                        child: Icon(
                                          Icons.remove,
                                          size: 18,
                                          color: _servings > 1
                                              ? const Color(0xFF161B24)
                                              : const Color(0x66161B24),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '$_servings',
                                          style: const TextStyle(
                                            color: Color(0xFF161B24),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            setState(() => _servings += 1),
                                        child: const Icon(
                                          Icons.add,
                                          size: 18,
                                          color: Color(0xFF161B24),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              result?.mealTitle ?? 'Scanned Meal',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF161B24),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (foods.isNotEmpty) ...[
                              Text(
                                foods
                                    .map((food) {
                                      final name =
                                          food['name']?.toString() ?? '';
                                      final grams = food['estimated_grams'];
                                      final usdaDescription =
                                          food['usda_description']?.toString();
                                      final portionEstimated =
                                          food['portion_estimated'] == true;
                                      final label =
                                          usdaDescription == null ||
                                              usdaDescription.isEmpty
                                          ? name
                                          : '$name — $usdaDescription';
                                      if (grams is! num) return label;
                                      final portionLabel =
                                          '~${grams.round()} g'
                                          '${portionEstimated ? ' estimate' : ''}';
                                      return '$label ($portionLabel)';
                                    })
                                    .join(' • '),
                                style: const TextStyle(
                                  color: Color(0xFF475467),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const Text(
                              'Your photo is sent to OpenAI for identification. Food and portion sizes are estimates; compare the USDA match and review nutrition before saving.',
                              style: TextStyle(
                                color: Color(0xFF475467),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if ((result?.confidence ?? 1) < 0.7)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1DE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFC97A),
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Color(0xFFB56A00),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI confidence is low. You can edit nutrition values manually.',
                                        style: TextStyle(
                                          color: Color(0xFFB56A00),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.35,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              children: [
                                _macroCard(
                                  label: 'Calories',
                                  value:
                                      '${(result?.calories ?? 0) * _servings}',
                                  icon: Icons.local_fire_department,
                                  color: const Color(0xFFFFC446),
                                  onEdit: () => _editValue(
                                    'Calories',
                                    (result?.calories ?? 0) * _servings,
                                  ),
                                ),
                                _macroCard(
                                  label: 'Protein',
                                  value:
                                      '${((result?.protein ?? 0) * _servings).toStringAsFixed(0)}gm',
                                  icon: Icons.science,
                                  color: const Color(0xFF4CB2FF),
                                  onEdit: () => _editValue(
                                    'Protein',
                                    (result?.protein ?? 0) * _servings,
                                  ),
                                ),
                                _macroCard(
                                  label: 'Carbs',
                                  value:
                                      '${((result?.carbs ?? 0) * _servings).toStringAsFixed(0)}gm',
                                  icon: Icons.spa,
                                  color: const Color(0xFF8F5DFF),
                                  onEdit: () => _editValue(
                                    'Carbs',
                                    (result?.carbs ?? 0) * _servings,
                                  ),
                                ),
                                _macroCard(
                                  label: 'Fat',
                                  value:
                                      '${((result?.fat ?? 0) * _servings).toStringAsFixed(0)}gm',
                                  icon: Icons.opacity,
                                  color: const Color(0xFF7CCB6D),
                                  onEdit: () => _editValue(
                                    'Fat',
                                    (result?.fat ?? 0) * _servings,
                                  ),
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
                                onPressed: _saving ? null : _done,
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Done',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
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
      color: Colors.white,
      borderColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF161B24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultTopIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
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
