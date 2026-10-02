// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/display_settings.dart';

/// The haptic patterns used by the motion spec.
enum Haptic {
  /// Picking up or tapping a piece.
  selection,

  /// A move lands; also the 10-second clock tick.
  light,

  /// A capture or the end of the game.
  medium,

  /// Your king is in check.
  heavy;

  Future<void> _fire() => switch (this) {
    Haptic.selection => HapticFeedback.selectionClick(),
    Haptic.light => HapticFeedback.lightImpact(),
    Haptic.medium => HapticFeedback.mediumImpact(),
    Haptic.heavy => HapticFeedback.heavyImpact(),
  };
}

extension HapticRef on WidgetRef {
  /// Plays [haptic], unless Haptic feedback is off in Settings.
  void haptic(Haptic haptic) {
    if (read(hapticsEnabledProvider)) haptic._fire();
  }
}
