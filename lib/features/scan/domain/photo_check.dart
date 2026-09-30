import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// What the phone can tell about a cropped board photo on its own, before
/// spending a Gemini request on it.
@immutable
class PhotoCheck {
  const PhotoCheck({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.boardScore,
  });

  /// Mean luminance, 0–255.
  final double brightness;

  /// Standard deviation of luminance, 0–255.
  final double contrast;

  /// Variance of the Laplacian at [side] pixels: low when blurred.
  final double sharpness;

  /// How much the 8 × 8 cells alternate light and dark like a chess board,
  /// 0 (not at all) to 1 (a perfect checkerboard).
  final double boardScore;

  /// Working size: enough for 64 squares, quick to measure.
  static const side = 256;

  /// Thresholds, kept conservative: the check only warns, and a real board
  /// in odd light must still get through.
  static const darkBelow = 35.0;
  static const flatBelow = 18.0;
  static const blurryBelow = 12.0;
  static const boardFrom = 0.35;

  /// Almost black, with little in it.
  bool get tooDark => brightness < darkBelow && contrast < flatBelow * 1.5;

  /// Too soft to read pieces from.
  bool get tooBlurry => sharpness < blurryBelow;

  bool get looksLikeBoard => boardScore >= boardFrom;

  /// Checks [jpeg] off the UI thread. Null if it can't be decoded.
  static Future<PhotoCheck?> of(Uint8List jpeg) => compute(_checkBytes, jpeg);

  /// Checks an image (any size; it is scaled to [side] × [side]).
  static PhotoCheck ofImage(img.Image image) {
    final gray = img.grayscale(
      img.copyResize(image, width: side, height: side, interpolation: img.Interpolation.average),
    );
    final lum = List<double>.filled(side * side, 0);
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        lum[y * side + x] = gray.getPixel(x, y).luminance.toDouble();
      }
    }
    final mean = lum.reduce((a, b) => a + b) / lum.length;
    final variance = lum.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / lum.length;
    return PhotoCheck(
      brightness: mean,
      contrast: math.sqrt(variance),
      sharpness: _laplacianVariance(lum),
      boardScore: _boardScore(lum),
    );
  }

  static double _laplacianVariance(List<double> lum) {
    final values = <double>[];
    for (var y = 1; y < side - 1; y++) {
      for (var x = 1; x < side - 1; x++) {
        final i = y * side + x;
        values.add(lum[i - 1] + lum[i + 1] + lum[i - side] + lum[i + side] - 4 * lum[i]);
      }
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    return values.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / values.length;
  }

  /// The best checkerboard fit over a few placements of the 8 × 8 grid:
  /// a crop is rarely exact, and a little table around the board (or a
  /// board edge cut off) would shift every square.
  static double _boardScore(List<double> lum) {
    var best = 0.0;
    for (final inset in const [0.0, 0.02, 0.04, 0.06, 0.08, 0.10]) {
      for (final dx in const [-0.02, 0.0, 0.02]) {
        for (final dy in const [-0.02, 0.0, 0.02]) {
          final size = side * (1 - 2 * inset);
          final x0 = side * (inset + dx);
          final y0 = side * (inset + dy);
          best = math.max(best, _gridScore(lum, x0, y0, size));
        }
      }
    }
    return best;
  }

  /// Pieces stand in the middle of their squares, so each square is sampled
  /// near its four corners and the median taken; then the 64 values are
  /// correlated with the light/dark checkerboard pattern (either colour
  /// first). The grid is [size] pixels wide from ([x0], [y0]).
  static double _gridScore(List<double> lum, double x0, double y0, double size) {
    final cell = size / 8;
    final patchSize = (cell * 0.14).round().clamp(2, 64);
    double patch(double px0, double py0) {
      var sum = 0.0;
      for (var y = 0; y < patchSize; y++) {
        for (var x = 0; x < patchSize; x++) {
          final px = (px0 + x).clamp(0, side - 1).toInt();
          final py = (py0 + y).clamp(0, side - 1).toInt();
          sum += lum[py * side + px];
        }
      }
      return sum / (patchSize * patchSize);
    }

    final cells = <double>[];
    final pattern = <double>[];
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final left = x0 + col * cell;
        final top = y0 + row * cell;
        final inset = cell * 0.08;
        final far = cell * (1 - 0.08 - 0.14);
        final corners = [
          patch(left + inset, top + inset),
          patch(left + far, top + inset),
          patch(left + inset, top + far),
          patch(left + far, top + far),
        ]..sort();
        cells.add((corners[1] + corners[2]) / 2);
        pattern.add((row + col).isEven ? 1 : -1);
      }
    }
    final mean = cells.reduce((a, b) => a + b) / cells.length;
    var covariance = 0.0;
    var spread = 0.0;
    for (var i = 0; i < cells.length; i++) {
      covariance += (cells[i] - mean) * pattern[i];
      spread += (cells[i] - mean) * (cells[i] - mean);
    }
    // All cells alike: no pattern (and no division by zero).
    if (spread / cells.length < 4) return 0;
    return (covariance / math.sqrt(spread * cells.length)).abs();
  }
}

PhotoCheck? _checkBytes(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  return image == null ? null : PhotoCheck.ofImage(image);
}
