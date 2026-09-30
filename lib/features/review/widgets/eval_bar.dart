import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/move_review.dart';
import '../domain/position_eval.dart';
import 'quality_chip.dart' show formatEval;

/// Who is better in the position on the board, as a horizontal bar of
/// winning chances. It follows the board: the side at the bottom (the
/// player's) is on the left. The number sits inside the side that is ahead,
/// without a sign, as chess sites show it: `1.2`, `M3`, `1–0`. Slides as the
/// position changes.
class EvalBar extends ConsumerWidget {
  const EvalBar({
    super.key,
    required this.eval,
    required this.toMove,
    this.orientation = Side.white,
    this.signed = false,
  });

  /// Null while the position isn't analysed yet (shown level, no number).
  final PositionEval? eval;
  final Side toMove;

  /// The side at the bottom of the board, shown on the left.
  final Side orientation;

  /// Shows the number with its sign from White's side (`+0.4`, `−1.8`), as
  /// the analysis board does.
  final bool signed;

  static const height = 26.0;

  // Piece colours from the design, so the bar reads as "the white pieces"
  // and "the black pieces" in both themes.
  static const _white = Color(0xFFF5F7FA);
  static const _whiteShade = Color(0xFFDCE2EA);
  static const _black = Color(0xFF1E2530);
  static const _blackShade = Color(0xFF141A22);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eval = this.eval;
    final whitePawns = eval?.pawnsFor(Side.white, toMove);
    final ahead = whitePawns == null ? null : (whitePawns >= 0 ? Side.white : Side.black);
    final whiteShare = whiteShareOf(eval, toMove);
    // The left side's share of the bar.
    final leftShare = orientation == Side.white ? whiteShare : 1 - whiteShare;
    final label = eval == null
        ? null
        : (signed ? signedEvalLabel(eval, toMove) : evalLabel(eval, toMove));
    final reduce = shouldReduceMotion(context, ref);

    Color face(Side side) => side == Side.white ? _white : _black;
    LinearGradient sheen(Side side) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: side == Side.white ? const [_white, _whiteShade] : const [_black, _blackShade],
    );

    return Semantics(
      label: label == null
          ? 'Evaluation not known yet'
          : 'Evaluation $label, ${ahead == Side.white ? 'White' : 'Black'} is better',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 6),
        // Clip the fills to the rounded shape, then draw the outline on top
        // of them, so the ends stay whole whatever the fill covers.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            decoration: BoxDecoration(gradient: sheen(orientation.opposite)),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              // Tertiary text contrasts with the page in both themes, so the
              // black half stays outlined on dark and the white half on light.
              border: Border.all(
                color: context.colors.textTertiary.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    // The left side's colour, growing from the left.
                    AnimatedContainer(
                      duration: reduce ? Duration.zero : const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: width * leftShare,
                      decoration: BoxDecoration(
                        gradient: sheen(orientation),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(1, 0),
                          ),
                        ],
                      ),
                    ),
                    if (label != null && ahead != null)
                      Align(
                        alignment: ahead == orientation
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _Label(
                            text: label,
                            // Dark text on white's side, light on black's.
                            color: face(ahead.opposite),
                            background: face(ahead),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// White's share of the bar (0–1): its winning chances, kept between 3%
  /// and 97% while the game is open, full once a mate is on the board.
  static double whiteShareOf(PositionEval? eval, Side toMove) {
    if (eval == null) return 0.5;
    final whitePawns = eval.pawnsFor(Side.white, toMove);
    if (eval.score.mate != null) return whitePawns >= 0 ? 1 : 0;
    return (winPercent(whitePawns) / 100).clamp(0.03, 0.97);
  }
}

/// The number, as a small pill inside the winning side.
class _Label extends StatelessWidget {
  const _Label({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(9)),
      child: Text(
        text,
        style: context.type.mono.copyWith(
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// The evaluation as chess sites show it on the bar, without a sign (its
/// side says who is better): `1.2`, `M3` (mate in 3), or `1–0` / `0–1` once
/// a side is mated.
String evalLabel(PositionEval eval, Side toMove) {
  final mate = eval.score.mate;
  if (mate != null) {
    if (mate == 0) return toMove == Side.white ? '0–1' : '1–0';
    return 'M${mate.abs()}';
  }
  return eval.pawnsFor(Side.white, toMove).abs().toStringAsFixed(1);
}

/// The evaluation with White's sign: `+0.4`, `−1.8`, `M3` (whoever mates),
/// `1–0` / `0–1` once a side is mated.
String signedEvalLabel(PositionEval eval, Side toMove) {
  if (eval.score.mate != null) return evalLabel(eval, toMove);
  return formatEval(eval.pawnsFor(Side.white, toMove));
}

/// The evaluation in words, naming the side that is better: `White +0.4`,
/// `Black mates in 2`, `equal`, `checkmate`.
String evalSummary(PositionEval eval, Side toMove) {
  final mate = eval.score.mate;
  final whitePawns = eval.pawnsFor(Side.white, toMove);
  final ahead = whitePawns >= 0 ? 'White' : 'Black';
  if (mate != null) return mate == 0 ? 'checkmate' : '$ahead mates in ${mate.abs()}';
  final pawns = whitePawns.abs();
  if (pawns < 0.05) return 'equal';
  return '$ahead +${pawns.toStringAsFixed(1)}';
}
