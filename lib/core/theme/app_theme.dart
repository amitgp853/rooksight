import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the Material theme from the design tokens. Dark is the default.
abstract final class AppTheme {
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final type = AppTypography.withColor(c.textPrimary);
    final buttonText = type.heading.copyWith(fontSize: 16, height: 1);
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.smAll);
    const buttonSize = Size(AppSpacing.minTouchTarget, AppSpacing.buttonHeight);
    final disabledText = c.textTertiary.withValues(alpha: 0.6);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.focus,
      onPrimary: c.onFocus,
      secondary: c.brass,
      onSecondary: c.onFocus,
      error: c.coral,
      onError: c.onFocus,
      surface: c.bgBase,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLow: c.bgRaised,
      surfaceContainer: c.bgRaised,
      surfaceContainerHigh: c.bgElevated,
      surfaceContainerHighest: c.bgElevated,
      outline: c.border,
      outlineVariant: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgBase,
      extensions: [c, type],
      textTheme: TextTheme(
        displayLarge: type.display,
        displayMedium: type.display,
        displaySmall: type.display,
        headlineSmall: type.title,
        titleLarge: type.title,
        titleMedium: type.heading,
        titleSmall: type.label,
        bodyLarge: type.body,
        bodyMedium: type.body,
        bodySmall: type.label.copyWith(color: c.textSecondary),
        labelLarge: type.label,
        labelMedium: type.label,
        labelSmall: type.overline.copyWith(color: c.textSecondary),
      ),
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgBase,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.heading,
      ),
      // Primary button.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.focus,
          foregroundColor: c.onFocus,
          disabledBackgroundColor: c.bgElevated,
          disabledForegroundColor: disabledText,
          minimumSize: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      // Secondary button.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.bgElevated,
          foregroundColor: c.textPrimary,
          disabledForegroundColor: disabledText,
          side: BorderSide(color: c.border),
          minimumSize: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      // Ghost button.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.focus,
          disabledForegroundColor: disabledText,
          minimumSize: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          minimumSize: const Size.square(48),
          shape: buttonShape,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.bgRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgElevated,
        modalBarrierColor: Colors.black.withValues(alpha: 0.55),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      // The date range picker (Games search): the app's surfaces and type.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.bgRaised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.bgRaised,
        headerForegroundColor: c.textPrimary,
        headerHeadlineStyle: type.title,
        headerHelpStyle: type.overline.copyWith(color: c.textSecondary),
        weekdayStyle: type.label.copyWith(color: c.textTertiary),
        dayStyle: type.body,
        rangePickerBackgroundColor: c.bgBase,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerHeaderBackgroundColor: c.bgBase,
        rangePickerHeaderForegroundColor: c.textPrimary,
        rangePickerHeaderHeadlineStyle: type.title,
        rangePickerHeaderHelpStyle: type.overline.copyWith(color: c.textSecondary),
        rangeSelectionBackgroundColor: c.focus.withValues(alpha: 0.18),
        todayBorder: BorderSide(color: c.focus),
        dividerColor: c.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgElevated,
        hintStyle: type.body.copyWith(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s4,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: c.focus, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onFocus : c.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.focus : c.bgElevated,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.border),
      ),
    );
  }
}

/// Shorthand access to the design tokens: `context.colors.focus`,
/// `context.type.heading`.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  AppTypography get type => Theme.of(this).extension<AppTypography>()!;
}
