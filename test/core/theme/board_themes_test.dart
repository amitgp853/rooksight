import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/theme/board_themes.dart';

/// Largest per-channel difference (0–255) between two colours.
int _distance(Color a, Color b) {
  int channel(double v) => (v * 255).round();
  return [
    (channel(a.r) - channel(b.r)).abs(),
    (channel(a.g) - channel(b.g)).abs(),
    (channel(a.b) - channel(b.b)).abs(),
  ].reduce((x, y) => x > y ? x : y);
}

void main() {
  // chessground draws one overlay on both last-move squares; it must land close
  // to the designed tint on light and dark squares alike.
  for (final theme in BoardTheme.values) {
    test('${theme.label} last-move overlay matches the designed tints', () {
      final onLight = Color.alphaBlend(theme.lastMoveOverlay, theme.lightSquare);
      final onDark = Color.alphaBlend(theme.lastMoveOverlay, theme.darkSquare);
      expect(_distance(onLight, theme.lastMoveLight), lessThanOrEqualTo(12));
      expect(_distance(onDark, theme.lastMoveDark), lessThanOrEqualTo(12));
    });
  }
}
