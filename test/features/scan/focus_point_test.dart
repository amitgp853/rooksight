// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/features/scan/domain/focus_point.dart';

void main() {
  const view = Size(400, 800);

  test('the centre of the screen is the centre of the frame', () {
    expect(
      focusPointForTap(const Offset(200, 400), view, const Size(720, 1280)),
      const Offset(0.5, 0.5),
    );
  });

  test('a preview wider than the screen is cropped at the sides', () {
    // 720×1280 covers 400×800 at a scale of 0.625: 450 wide, 25 cut off each side.
    final point = focusPointForTap(const Offset(0, 800), view, const Size(720, 1280));
    expect(point.dx, closeTo(25 / 450, 1e-9));
    expect(point.dy, 1);
  });

  test('a preview taller than the screen is cropped top and bottom', () {
    // 400×1000 covers 400×800 at a scale of 1: 100 cut off top and bottom.
    final point = focusPointForTap(const Offset(100, 0), view, const Size(400, 1000));
    expect(point.dx, 0.25);
    expect(point.dy, closeTo(0.1, 1e-9));
  });

  test('without a preview size the screen is the frame', () {
    expect(focusPointForTap(const Offset(100, 600), view, null), const Offset(0.25, 0.75));
  });
}
