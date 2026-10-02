// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';

/// Corner radii from the design system.
abstract final class AppRadius {
  /// Quality chips.
  static const double xs = 6;

  /// Buttons, inputs.
  static const double sm = 12;

  /// Cards.
  static const double md = 16;

  /// Sheets.
  static const double lg = 24;

  /// Pills. Large enough to fully round any control.
  static const double full = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
