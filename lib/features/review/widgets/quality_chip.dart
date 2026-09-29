import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/move_review.dart';

/// The design's colour for a move mark. Always shown with its symbol.
Color qualityColor(AppColors colors, MoveQuality quality) => switch (quality) {
  MoveQuality.brilliant => colors.moveBrilliant,
  MoveQuality.best => colors.moveBest,
  MoveQuality.inaccuracy => colors.moveInaccuracy,
  MoveQuality.mistake => colors.moveMistake,
  MoveQuality.blunder => colors.moveBlunder,
};

/// A round disc with the mark's symbol (`??`, `!`, …).
class QualityDisc extends StatelessWidget {
  const QualityDisc({super.key, required this.quality, this.size = 20});

  final MoveQuality quality;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size,
      padding: EdgeInsets.symmetric(horizontal: size * 0.15),
      decoration: BoxDecoration(
        color: qualityColor(colors, quality),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      // Sized to the symbol, never stretched to the space around it.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          quality.symbol,
          style: context.type.heading.copyWith(
            fontSize: size * 0.5,
            height: 1,
            fontWeight: FontWeight.w700,
            color: AppColors.dark.onFocus,
          ),
        ),
      ),
    );
  }
}

/// Quality chip from the design system: radius 6, symbol first.
class QualityChip extends StatelessWidget {
  const QualityChip({super.key, required this.quality});

  final MoveQuality quality;

  @override
  Widget build(BuildContext context) {
    final colour = qualityColor(context.colors, quality);
    return Container(
      height: 28,
      padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: AppRadius.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          QualityDisc(quality: quality),
          Text(
            quality.label,
            style: context.type.label.copyWith(fontWeight: FontWeight.w600, color: colour),
          ),
        ],
      ),
    );
  }
}

/// `+0.4`, `−2.9`, `0.0`: an evaluation in pawns, with a real minus sign.
String formatEval(double pawns) {
  if (pawns >= 10) return '+10';
  if (pawns <= -10) return '−10';
  final text = pawns.abs().toStringAsFixed(1);
  if (text == '0.0') return '0.0';
  return pawns > 0 ? '+$text' : '−$text';
}
