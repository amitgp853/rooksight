// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

/// 4-pt spacing scale. Names follow the design tokens (`space.1` = 4px).
abstract final class AppSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s14 = 56;

  /// Horizontal screen padding. Chess boards ignore it and run edge to edge.
  static const double gutter = s4;

  /// Standard button height (the minimum touch target is 44).
  static const double buttonHeight = 52;
  static const double minTouchTarget = 44;
}
