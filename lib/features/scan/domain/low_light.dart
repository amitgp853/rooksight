// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Decides from the camera preview's brightness whether to suggest more
/// light. It switches only after [confirmations] readings in a row, and uses
/// two thresholds (dark below [darkBelow], bright again above [brightAbove])
/// so a room on the edge doesn't make the hint flicker.
class LowLightDetector {
  LowLightDetector({this.darkBelow = 55, this.brightAbove = 75, this.confirmations = 2});

  /// Mean luma (0–255) under which the preview counts as dark.
  final double darkBelow;

  /// Mean luma above which it counts as bright again.
  final double brightAbove;
  final int confirmations;

  bool _dark = false;
  int _streak = 0;

  /// Whether the preview is currently judged too dark.
  bool get isDark => _dark;

  /// Takes one brightness reading; returns [isDark] afterwards.
  bool update(double luma) {
    final wantsChange = _dark ? luma > brightAbove : luma < darkBelow;
    _streak = wantsChange ? _streak + 1 : 0;
    if (_streak >= confirmations) {
      _dark = !_dark;
      _streak = 0;
    }
    return _dark;
  }

  /// Starts over (e.g. the camera restarted).
  void reset() {
    _dark = false;
    _streak = 0;
  }
}

/// Samples in each direction when measuring a frame: enough for an average,
/// cheap enough for every second.
const _grid = 24;

/// Mean brightness of a luma plane (Android's YUV / NV21 first plane): one
/// byte per pixel, [rowStride] bytes a row.
double? lumaOfYPlane(
  Uint8List bytes, {
  required int width,
  required int height,
  required int rowStride,
}) {
  if (width <= 0 || height <= 0) return null;
  var sum = 0;
  var count = 0;
  for (var gy = 0; gy < _grid; gy++) {
    final y = (height * (gy + 0.5) / _grid).floor();
    for (var gx = 0; gx < _grid; gx++) {
      final x = (width * (gx + 0.5) / _grid).floor();
      final i = y * rowStride + x;
      if (i < 0 || i >= bytes.length) continue;
      sum += bytes[i];
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}

/// Mean brightness of a BGRA frame (iOS): 4 bytes a pixel.
double? lumaOfBgra(
  Uint8List bytes, {
  required int width,
  required int height,
  required int rowStride,
}) {
  if (width <= 0 || height <= 0) return null;
  var sum = 0.0;
  var count = 0;
  for (var gy = 0; gy < _grid; gy++) {
    final y = (height * (gy + 0.5) / _grid).floor();
    for (var gx = 0; gx < _grid; gx++) {
      final x = (width * (gx + 0.5) / _grid).floor();
      final i = y * rowStride + x * 4;
      if (i < 0 || i + 2 >= bytes.length) continue;
      // Rec. 601 luma from B, G, R.
      sum += 0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2];
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}
