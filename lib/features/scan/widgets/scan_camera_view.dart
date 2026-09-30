import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/move_wise_sheet.dart';

/// The camera (`ScanCamera.dc.html`): a square guide frame with the rest of
/// the preview dimmed, flash, tips, the gallery and the shutter. Always dark.
class ScanCameraView extends ConsumerStatefulWidget {
  const ScanCameraView({
    super.key,
    required this.onPhoto,
    required this.onGallery,
    required this.onClose,
    this.showTipsFirst = false,
  });

  /// The picture just taken, as file bytes.
  final ValueChanged<Uint8List> onPhoto;
  final VoidCallback onGallery;
  final VoidCallback onClose;

  /// Opens "Tips for a good scan" straight away (after several photos in a
  /// row that couldn't be read).
  final bool showTipsFirst;

  @override
  ConsumerState<ScanCameraView> createState() => _ScanCameraViewState();
}

class _ScanCameraViewState extends ConsumerState<ScanCameraView> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _flash = false;
  bool _taking = false;

  /// The white flash over the preview when a photo is taken.
  bool _flashOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
    if (widget.showTipsFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTips();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera is released while the app is in the background.
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      _camera = null;
      unawaited(camera.dispose());
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _camera == null && _error == null) {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'This phone has no camera we can use.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      if (_flash) await camera.setFlashMode(FlashMode.torch);
      setState(() {
        _camera = camera;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
            'MoveWise isn’t allowed to use the camera. You can allow it in your phone’s '
                'settings, or upload a photo instead.',
          _ => 'The camera couldn’t start. You can upload a photo instead.',
        },
      );
    } on Object {
      if (mounted) {
        setState(() => _error = 'The camera couldn’t start. You can upload a photo instead.');
      }
    }
  }

  Future<void> _toggleFlash() async {
    final on = !_flash;
    setState(() => _flash = on);
    try {
      await _camera?.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } on CameraException {
      if (mounted) setState(() => _flash = false);
    }
  }

  Future<void> _take() async {
    final camera = _camera;
    if (camera == null || _taking || !camera.value.isInitialized) return;
    setState(() => _taking = true);
    final reduce = shouldReduceMotion(context, ref);
    try {
      if (!reduce) setState(() => _flashOverlay = true);
      unawaited(HapticFeedback.lightImpact());
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      // The photo isn't kept: only the bytes in memory, until the scan ends.
      unawaited(File(file.path).delete().then((_) {}, onError: (_) {}));
      if (_flash) await camera.setFlashMode(FlashMode.off);
      if (mounted) widget.onPhoto(bytes);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn’t take the photo. Try again.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _taking = false;
          _flashOverlay = false;
        });
      }
    }
  }

  Future<void> _focus(TapUpDetails details, Size size) async {
    final camera = _camera;
    if (camera == null || !camera.value.focusPointSupported) return;
    final point = Offset(
      (details.localPosition.dx / size.width).clamp(0, 1),
      (details.localPosition.dy / size.height).clamp(0, 1),
    );
    try {
      await camera.setFocusPoint(point);
      await camera.setExposurePoint(point);
    } on CameraException {
      // Not every camera can; the preview just stays as it is.
    }
  }

  void _showTips() {
    unawaited(
      showMoveWiseSheet<void>(
        context,
        reduceMotion: shouldReduceMotion(context, ref),
        builder: (context) => const ScanTipsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final reduce = shouldReduceMotion(context, ref);
    return ColoredBox(
      color: const Color(0xFF050709),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final frame = (size.width - 44).clamp(200.0, 420.0);
          final frameTop = (size.height * 0.28).clamp(120.0, size.height - frame - 200);
          final frameRect = Rect.fromLTWH((size.width - frame) / 2, frameTop, frame, frame);

          return Stack(
            children: [
              if (camera != null && camera.value.isInitialized)
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: (d) => _focus(d, size),
                    child: _CoverPreview(camera: camera),
                  ),
                )
              else if (_error == null)
                const Center(child: CircularProgressIndicator(color: Color(0xFFF5F7FA))),
              if (_error == null) ...[
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _GuidePainter(frameRect))),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: frameRect.top - 62,
                  child: const Center(child: _Pill('Fit the whole board inside the frame')),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: frameRect.bottom + 20,
                  child: Center(
                    child: TextButton.icon(
                      onPressed: _showTips,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC9D7FF),
                        textStyle: context.type.label.copyWith(fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: const Text('Tips for a good scan'),
                    ),
                  ),
                ),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.s4,
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          size: 40,
                          color: Color(0xFFA3AFBD),
                        ),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: context.type.body.copyWith(color: const Color(0xFFE9EDF2)),
                        ),
                        FilledButton.icon(
                          onPressed: widget.onGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Upload a photo'),
                        ),
                      ],
                    ),
                  ),
                ),
              // Capture flash.
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _flashOverlay && !reduce ? 0.85 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          _RoundButton(
                            tooltip: 'Close',
                            icon: Icons.close_rounded,
                            onPressed: widget.onClose,
                          ),
                          Expanded(
                            child: Text(
                              'Scan a board',
                              textAlign: TextAlign.center,
                              style: context.type.heading.copyWith(
                                fontSize: 16,
                                color: const Color(0xFFF5F7FA),
                                shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)],
                              ),
                            ),
                          ),
                          if (_error == null)
                            _RoundButton(
                              tooltip: _flash ? 'Flash on' : 'Flash off',
                              icon: _flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              active: _flash,
                              onPressed: _toggleFlash,
                            )
                          else
                            const SizedBox(width: 44),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00050709), Color(0xD9050709)],
                      stops: [0, 0.45],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 148,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Semantics(
                              button: true,
                              label: 'Upload a photo from your gallery',
                              excludeSemantics: true,
                              child: InkWell(
                                onTap: widget.onGallery,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: const Color(0xFF151B22),
                                    border: Border.all(color: const Color(0xD9F5F7FA), width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    color: Color(0xFFF5F7FA),
                                  ),
                                ),
                              ),
                            ),
                            if (_error == null)
                              Semantics(
                                button: true,
                                label: 'Take photo',
                                excludeSemantics: true,
                                child: GestureDetector(
                                  onTap: _take,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFF5F7FA), width: 4),
                                    ),
                                    child: Center(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 120),
                                        width: _taking ? 52 : 62,
                                        height: _taking ? 52 : 62,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFF5F7FA),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 56, height: 56),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The preview filling the screen, cropped rather than letterboxed.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.camera});

  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    final preview = camera.value.previewSize;
    if (preview == null) return CameraPreview(camera);
    // The preview size is reported landscape; the phone is held upright.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: preview.height, height: preview.width, child: CameraPreview(camera)),
      ),
    );
  }
}

/// Dims everything outside the frame and draws its corner brackets.
class _GuidePainter extends CustomPainter {
  _GuidePainter(this.frame);

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(frame, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rounded),
      ),
      Paint()..color = const Color(0x94050709),
    );
    final bracket = Paint()
      ..color = const Color(0xFFF5F7FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const arm = 40.0;
    const r = 18.0;
    for (final (x, y, sx, sy) in [
      (frame.left, frame.top, 1.0, 1.0),
      (frame.right, frame.top, -1.0, 1.0),
      (frame.left, frame.bottom, 1.0, -1.0),
      (frame.right, frame.bottom, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(x, y + sy * arm)
        ..lineTo(x, y + sy * r)
        ..arcToPoint(
          Offset(x + sx * r, y),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(x + sx * arm, y);
      canvas.drawPath(path, bracket);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.frame != frame;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB8080B0F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: context.type.label.copyWith(fontSize: 14, color: const Color(0xFFF5F7FA)),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: active,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: active ? const Color(0xFFE3B25C) : const Color(0x8C080B0F),
        foregroundColor: active ? const Color(0xFF1A1204) : const Color(0xFFF5F7FA),
      ),
    );
  }
}

/// "Tips for a good scan" (`ScanCameraTips.dc.html`).
class ScanTipsSheet extends StatelessWidget {
  const ScanTipsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    const tips = [
      (
        Icons.wb_sunny_outlined,
        'Good, even light',
        'Daylight or a lamp above works best. Avoid glare and strong shadows on the pieces.',
      ),
      (
        Icons.crop_free_rounded,
        'The whole board in view',
        'All 64 squares and every piece, with a little space around the edge.',
      ),
      (
        Icons.vertical_align_bottom_rounded,
        'Shoot from above',
        'Hold the phone flat over the board. A steep angle hides pieces behind each other.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text('Tips for a good scan', style: type.title.copyWith(fontSize: 20)),
        for (final (icon, title, text) in tips)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: colors.focus),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(title, style: type.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      text,
                      style: type.label.copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 2),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
      ],
    );
  }
}
