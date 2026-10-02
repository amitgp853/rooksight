// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

/// Colour tokens from the "Night Study" design system (`design/design-spec.md`).
///
/// Every token has a dark (default) and a light value. Read them with
/// `context.colors` (see `app_theme.dart`).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgBase,
    required this.bgRaised,
    required this.bgElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.focus,
    required this.onFocus,
    required this.brass,
    required this.moveBrilliant,
    required this.moveBest,
    required this.moveInaccuracy,
    required this.moveMistake,
    required this.moveBlunder,
    required this.resultWin,
    required this.resultDraw,
    required this.resultLoss,
  });

  /// App background.
  final Color bgBase;

  /// Cards, rows.
  final Color bgRaised;

  /// Inputs, sheets, pressed states.
  final Color bgElevated;

  /// Hairlines, outlines.
  final Color border;

  /// Headings, body.
  final Color textPrimary;

  /// Supporting copy.
  final Color textSecondary;

  /// Captions, meta.
  final Color textTertiary;

  /// Primary action, your side.
  final Color focus;

  /// Text and icons on [focus] fills.
  final Color onFocus;

  /// Hints, brilliancies, last move. Use sparingly.
  final Color brass;

  // Move quality. Never use these without the quality symbol next to them.
  final Color moveBrilliant;
  final Color moveBest;
  final Color moveInaccuracy;
  final Color moveMistake;

  /// Also used for check glow and the illegal-move flash (coral).
  final Color moveBlunder;

  // Results (stats bars).
  final Color resultWin;
  final Color resultDraw;
  final Color resultLoss;

  static const dark = AppColors(
    bgBase: Color(0xFF0E1217),
    bgRaised: Color(0xFF151B22),
    bgElevated: Color(0xFF1C242E),
    border: Color(0xFF2A3441),
    textPrimary: Color(0xFFE9EDF2),
    textSecondary: Color(0xFFA3AFBD),
    textTertiary: Color(0xFF7C8898),
    focus: Color(0xFF86A8FF),
    onFocus: Color(0xFF0B1224),
    brass: Color(0xFFE3B25C),
    moveBrilliant: Color(0xFFE3B25C),
    moveBest: Color(0xFF86A8FF),
    moveInaccuracy: Color(0xFFE3C65C),
    moveMistake: Color(0xFFF09A55),
    moveBlunder: Color(0xFFF2677A),
    resultWin: Color(0xFF86A8FF),
    resultDraw: Color(0xFF7C8898),
    resultLoss: Color(0xFFF09A55),
  );

  static const light = AppColors(
    bgBase: Color(0xFFF1F3F6),
    bgRaised: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFE6EAF0),
    border: Color(0xFFD5DBE3),
    textPrimary: Color(0xFF121820),
    textSecondary: Color(0xFF4A5563),
    textTertiary: Color(0xFF5F6B7A),
    focus: Color(0xFF2F5BD3),
    onFocus: Color(0xFFFFFFFF),
    brass: Color(0xFF8A5F0F),
    moveBrilliant: Color(0xFF8A5F0F),
    moveBest: Color(0xFF2F5BD3),
    moveInaccuracy: Color(0xFF7A6200),
    moveMistake: Color(0xFFB4531A),
    moveBlunder: Color(0xFFC22F48),
    resultWin: Color(0xFF2F5BD3),
    resultDraw: Color(0xFF8A94A3),
    resultLoss: Color(0xFFB4531A),
  );

  /// Coral, for check glow and illegal-move flashes.
  Color get coral => moveBlunder;

  @override
  AppColors copyWith({
    Color? bgBase,
    Color? bgRaised,
    Color? bgElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? focus,
    Color? onFocus,
    Color? brass,
    Color? moveBrilliant,
    Color? moveBest,
    Color? moveInaccuracy,
    Color? moveMistake,
    Color? moveBlunder,
    Color? resultWin,
    Color? resultDraw,
    Color? resultLoss,
  }) {
    return AppColors(
      bgBase: bgBase ?? this.bgBase,
      bgRaised: bgRaised ?? this.bgRaised,
      bgElevated: bgElevated ?? this.bgElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      focus: focus ?? this.focus,
      onFocus: onFocus ?? this.onFocus,
      brass: brass ?? this.brass,
      moveBrilliant: moveBrilliant ?? this.moveBrilliant,
      moveBest: moveBest ?? this.moveBest,
      moveInaccuracy: moveInaccuracy ?? this.moveInaccuracy,
      moveMistake: moveMistake ?? this.moveMistake,
      moveBlunder: moveBlunder ?? this.moveBlunder,
      resultWin: resultWin ?? this.resultWin,
      resultDraw: resultDraw ?? this.resultDraw,
      resultLoss: resultLoss ?? this.resultLoss,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bgBase: mix(bgBase, other.bgBase),
      bgRaised: mix(bgRaised, other.bgRaised),
      bgElevated: mix(bgElevated, other.bgElevated),
      border: mix(border, other.border),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      focus: mix(focus, other.focus),
      onFocus: mix(onFocus, other.onFocus),
      brass: mix(brass, other.brass),
      moveBrilliant: mix(moveBrilliant, other.moveBrilliant),
      moveBest: mix(moveBest, other.moveBest),
      moveInaccuracy: mix(moveInaccuracy, other.moveInaccuracy),
      moveMistake: mix(moveMistake, other.moveMistake),
      moveBlunder: mix(moveBlunder, other.moveBlunder),
      resultWin: mix(resultWin, other.resultWin),
      resultDraw: mix(resultDraw, other.resultDraw),
      resultLoss: mix(resultLoss, other.resultLoss),
    );
  }
}
