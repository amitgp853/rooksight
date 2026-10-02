// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/scan_photo.dart';

/// "Crop to the board" (`ScanCrop.dc.html`): drag the corners so only the 64
/// squares are inside; the frame snaps back to a square on release. Always
/// dark, like the camera.
class ScanCropView extends ConsumerStatefulWidget {
  const ScanCropView({
    super.key,
    required this.photo,
    required this.busy,
    required this.onRetake,
    required this.onRotate,
    required this.onScan,
  });

  final ScanPhoto photo;

  /// Rotating or cropping: the buttons wait.
  final bool busy;
  final VoidCallback onRetake;
  final void Function({required bool clockwise}) onRotate;

  /// The crop, as fractions of the photo's width and height.
  final ValueChanged<Rect> onScan;

  @override
  ConsumerState<ScanCropView> createState() => _ScanCropViewState();
}

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, move }

class _ScanCropViewState extends ConsumerState<ScanCropView> {
  /// The crop in fractions of the photo: at first a centred square covering
  /// 90% of the short side.
  late Rect _crop = _initial(widget.photo);
  _Handle? _dragging;

  /// Smallest crop, in fractions of the photo's short side.
  static const _minSide = 0.2;

  @override
  void didUpdateWidget(ScanCropView old) {
    super.didUpdateWidget(old);
    // A rotated photo starts with a fresh frame.
    if (old.photo != widget.photo) _crop = _initial(widget.photo);
  }

  static Rect _initial(ScanPhoto photo) {
    final side = math.min(photo.width, photo.height) * 0.9;
    return Rect.fromCenter(
      center: const Offset(0.5, 0.5),
      width: side / photo.width,
      height: side / photo.height,
    );
  }

  static Rect _toFraction(Rect r, Size s) =>
      Rect.fromLTRB(r.left / s.width, r.top / s.height, r.right / s.width, r.bottom / s.height);

  static Rect _toPixels(Rect f, Size s) =>
      Rect.fromLTRB(f.left * s.width, f.top * s.height, f.right * s.width, f.bottom * s.height);

  _Handle _hit(Offset p, Rect r) {
    const reach = 32.0;
    final corners = {
      _Handle.topLeft: r.topLeft,
      _Handle.topRight: r.topRight,
      _Handle.bottomLeft: r.bottomLeft,
      _Handle.bottomRight: r.bottomRight,
    };
    for (final MapEntry(:key, :value) in corners.entries) {
      if ((p - value).distance <= reach) return key;
    }
    return _Handle.move;
  }

  void _drag(Offset delta, Size shown) {
    final r = _toPixels(_crop, shown);
    final bounds = Offset.zero & shown;
    final min = math.min(shown.width, shown.height) * _minSide;
    Rect next;
    switch (_dragging!) {
      case _Handle.move:
        final moved = r.shift(delta);
        final dx = moved.left < 0
            ? -moved.left
            : (moved.right > shown.width ? shown.width - moved.right : 0.0);
        final dy = moved.top < 0
            ? -moved.top
            : (moved.bottom > shown.height ? shown.height - moved.bottom : 0.0);
        next = moved.shift(Offset(dx, dy));
      case _Handle.topLeft:
        next = Rect.fromLTRB(
          (r.left + delta.dx).clamp(0, r.right - min),
          (r.top + delta.dy).clamp(0, r.bottom - min),
          r.right,
          r.bottom,
        );
      case _Handle.topRight:
        next = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(0, r.bottom - min),
          (r.right + delta.dx).clamp(r.left + min, bounds.right),
          r.bottom,
        );
      case _Handle.bottomLeft:
        next = Rect.fromLTRB(
          (r.left + delta.dx).clamp(0, r.right - min),
          r.top,
          r.right,
          (r.bottom + delta.dy).clamp(r.top + min, bounds.bottom),
        );
      case _Handle.bottomRight:
        next = Rect.fromLTRB(
          r.left,
          r.top,
          (r.right + delta.dx).clamp(r.left + min, bounds.right),
          (r.bottom + delta.dy).clamp(r.top + min, bounds.bottom),
        );
    }
    setState(() => _crop = _toFraction(next, shown));
  }

  /// Back to a square around the same centre, as large as the frame was on
  /// average and kept inside the photo.
  void _snap(Size shown) {
    final r = _toPixels(_crop, shown);
    var side = math.min((r.width + r.height) / 2, math.min(shown.width, shown.height));
    side = math.max(side, math.min(shown.width, shown.height) * _minSide);
    final left = (r.center.dx - side / 2).clamp(0.0, shown.width - side);
    final top = (r.center.dy - side / 2).clamp(0.0, shown.height - side);
    setState(() {
      _dragging = null;
      _crop = _toFraction(Rect.fromLTWH(left, top, side, side), shown);
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final reduce = shouldReduceMotion(context, ref);
    const fg = Color(0xFFE9EDF2);
    final outlined = OutlinedButton.styleFrom(
      foregroundColor: fg,
      backgroundColor: const Color(0xFF151B22),
      side: const BorderSide(color: Color(0xFF2A3441)),
    );

    return ColoredBox(
      color: const Color(0xFF0B0F13),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retake',
                    color: fg,
                    onPressed: widget.onRetake,
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Crop to the board', style: type.heading.copyWith(color: fg)),
                        Text(
                          'Drag the corners until the grid sits on the squares',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFA3AFBD),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final photo = widget.photo;
                    final scale = math.min(
                      constraints.maxWidth / photo.width,
                      constraints.maxHeight / photo.height,
                    );
                    final shown = Size(photo.width * scale, photo.height * scale);
                    final rect = _toPixels(_crop, shown);
                    return Center(
                      child: SizedBox.fromSize(
                        size: shown,
                        child: GestureDetector(
                          onPanStart: (d) => _dragging = _hit(d.localPosition, rect),
                          onPanUpdate: (d) => _drag(d.delta, shown),
                          onPanEnd: (_) => _snap(shown),
                          onPanCancel: () => _snap(shown),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    photo.bytes,
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                    semanticLabel: 'Your photo',
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: TweenAnimationBuilder<Rect?>(
                                  tween: RectTween(end: rect),
                                  duration: _dragging != null || reduce
                                      ? Duration.zero
                                      : const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, r, _) =>
                                      CustomPaint(painter: _CropPainter(r ?? rect)),
                                ),
                              ),
                              for (final (handle, point, label) in [
                                (_Handle.topLeft, rect.topLeft, 'Top-left corner'),
                                (_Handle.topRight, rect.topRight, 'Top-right corner'),
                                (_Handle.bottomLeft, rect.bottomLeft, 'Bottom-left corner'),
                                (_Handle.bottomRight, rect.bottomRight, 'Bottom-right corner'),
                              ])
                                Positioned(
                                  left: point.dx - 22,
                                  top: point.dy - 22,
                                  child: Semantics(
                                    label: label,
                                    child: IgnorePointer(
                                      child: SizedBox.square(
                                        dimension: 44,
                                        child: Center(
                                          child: AnimatedScale(
                                            scale: _dragging == handle && !reduce ? 1.2 : 1,
                                            duration: const Duration(milliseconds: 120),
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFFF5F7FA),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0xE686A8FF),
                                                    spreadRadius: 3,
                                                  ),
                                                  BoxShadow(
                                                    color: Color(0x80000000),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  style: outlined.copyWith(shape: const WidgetStatePropertyAll(StadiumBorder())),
                  onPressed: widget.busy ? null : () => widget.onRotate(clockwise: false),
                  icon: const Icon(Icons.rotate_left_rounded, size: 18),
                  label: const Text('Rotate left'),
                ),
                OutlinedButton.icon(
                  style: outlined.copyWith(shape: const WidgetStatePropertyAll(StadiumBorder())),
                  onPressed: widget.busy ? null : () => widget.onRotate(clockwise: true),
                  icon: const Icon(Icons.rotate_right_rounded, size: 18),
                  label: const Text('Rotate right'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: outlined.copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
                      ),
                      onPressed: widget.onRetake,
                      child: const Text('Retake'),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: const Color(0xFF86A8FF),
                        foregroundColor: const Color(0xFF0B1224),
                        textStyle: type.heading,
                      ),
                      onPressed: widget.busy ? null : () => widget.onScan(_crop),
                      icon: widget.busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Scan board'),
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
}

/// Dims outside the crop; outline and an 8 × 8 grid inside. The same grid
/// is drawn on the photo the AI reads, so lining it up with the board's
/// squares here is what keeps each piece on the right square.
class _CropPainter extends CustomPainter {
  _CropPainter(this.crop);

  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16))),
        Path()..addRect(crop),
      ),
      Paint()..color = const Color(0x9E050709),
    );
    final grid = Paint()
      ..color = const Color(0x59F5F7FA)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = crop.left + crop.width * i / 8;
      final y = crop.top + crop.height * i / 8;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }
    canvas.drawRect(
      crop,
      Paint()
        ..color = const Color(0xFFF5F7FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.crop != crop;
}
