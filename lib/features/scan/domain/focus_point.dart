import 'dart:math' as math;
import 'dart:ui';

/// Turns a tap on a preview that fills [view] with `BoxFit.cover` into the
/// camera's focus point: (0, 0) to (1, 1) across the whole, uncropped
/// [preview] (upright). Taps on the cropped-off parts can't happen, but the
/// result is clamped anyway.
///
/// Without a [preview] size the preview is taken to fill [view] exactly.
Offset focusPointForTap(Offset tap, Size view, Size? preview) {
  if (preview == null || preview.isEmpty) {
    return Offset((tap.dx / view.width).clamp(0, 1), (tap.dy / view.height).clamp(0, 1));
  }
  final scale = math.max(view.width / preview.width, view.height / preview.height);
  final shown = preview * scale;
  final left = (view.width - shown.width) / 2;
  final top = (view.height - shown.height) / 2;
  return Offset(
    ((tap.dx - left) / shown.width).clamp(0, 1),
    ((tap.dy - top) / shown.height).clamp(0, 1),
  );
}
