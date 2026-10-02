// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/display_settings.dart';

/// Whether animations should use their reduced versions (150ms fades, no
/// travel, scale or shake), per the motion spec.
///
/// True when either the system asks for it (`disableAnimations`) or the user
/// turned on "Reduce motion" in Settings.
bool shouldReduceMotion(BuildContext context, WidgetRef ref) {
  return MediaQuery.disableAnimationsOf(context) || ref.watch(reduceMotionSettingProvider);
}
