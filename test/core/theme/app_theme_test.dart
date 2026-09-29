import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/theme/app_colors.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/core/theme/app_typography.dart';

void main() {
  // google_fonts loads the bundled font files through the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AppColors', () {
    test('match the design spec', () {
      expect(AppColors.dark.bgBase, const Color(0xFF0E1217));
      expect(AppColors.dark.focus, const Color(0xFF86A8FF));
      expect(AppColors.dark.brass, const Color(0xFFE3B25C));
      expect(AppColors.light.bgBase, const Color(0xFFF1F3F6));
      expect(AppColors.light.focus, const Color(0xFF2F5BD3));
      expect(AppColors.light.moveBlunder, const Color(0xFFC22F48));
    });

    test('coral is the blunder colour', () {
      expect(AppColors.dark.coral, AppColors.dark.moveBlunder);
    });

    test('lerp returns the endpoints at 0 and 1', () {
      expect(AppColors.dark.lerp(AppColors.light, 0).bgBase, AppColors.dark.bgBase);
      expect(AppColors.dark.lerp(AppColors.light, 1).bgBase, AppColors.light.bgBase);
      expect(AppColors.dark.lerp(null, 0.5), same(AppColors.dark));
    });

    test('copyWith replaces only the given token', () {
      final copy = AppColors.dark.copyWith(focus: const Color(0xFF000000));
      expect(copy.focus, const Color(0xFF000000));
      expect(copy.brass, AppColors.dark.brass);
    });
  });

  group('AppTheme', () {
    for (final (name, theme, colors) in [
      ('dark', AppTheme.dark(), AppColors.dark),
      ('light', AppTheme.light(), AppColors.light),
    ]) {
      test('$name theme carries its tokens', () {
        expect(theme.extension<AppColors>(), same(colors));
        expect(theme.extension<AppTypography>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, colors.bgBase);
        expect(theme.colorScheme.primary, colors.focus);
      });
    }

    test('type scale uses the design fonts and sizes', () {
      final type = AppTheme.dark().extension<AppTypography>()!;
      expect(type.display.fontFamily, startsWith('Sora'));
      expect(type.display.fontSize, 40);
      expect(type.body.fontFamily, startsWith('InstrumentSans'));
      expect(type.mono.fontFamily, startsWith('JetBrainsMono'));
      expect(type.mono.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });
}
