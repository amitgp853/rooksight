import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../play/domain/game_state.dart';
import 'position_eval.dart';

/// Move marks from the design (`design/design-spec.md` > Semantic).
enum MoveQuality {
  brilliant('!!', 'Brilliant'),
  best('!', 'Best move'),
  inaccuracy('?!', 'Inaccuracy'),
  mistake('?', 'Mistake'),
  blunder('??', 'Blunder');

  const MoveQuality(this.symbol, this.label);

  final String symbol;
  final String label;

  bool get isError => index >= MoveQuality.inaccuracy.index;
}

/// Thresholds, in pawns lost against Stockfish's best move.
abstract final class ReviewRules {
  static const inaccuracy = 0.5;
  static const mistake = 1.0;
  static const blunder = 2.0;

  /// A move is only "the one good move" (`!`) if every alternative was at
  /// least this much worse.
  static const onlyMoveGap = 1.0;

  /// Still this far ahead after the move: inaccuracies and mistakes aren't
  /// flagged (going from +9 to +7 doesn't matter). Blunders always are.
  static const stillWinning = 4.0;

  /// `!` only while the game is still in the balance: once one side is this
  /// far ahead, "only moves" are mostly technique.
  static const balanced = 3.0;

  /// Material a move must put at risk (piece value minus anything it
  /// captured) to count as a sacrifice for `!!`.
  static const sacrificeValue = 2;
}

/// One move of a reviewed game.
@immutable
class MoveReview {
  const MoveReview({
    required this.index,
    required this.move,
    required this.before,
    required this.after,
    required this.loss,
    required this.accuracy,
    this.quality,
  });

  /// Index into the game's moves.
  final int index;
  final PlayedMove move;

  /// Evaluation in pawns from the mover's side, before (the best play) and
  /// after the move.
  final double before;
  final double after;

  /// Pawns lost against Stockfish's best move (never negative).
  final double loss;

  /// 0–100, Lichess's per-move accuracy.
  final double accuracy;
  final MoveQuality? quality;

  Side get side => move.side;
}

/// Reviews move [index] of [game] from Stockfish's evaluations of the
/// positions before ([evalBefore]) and after ([evalAfter]) it.
MoveReview reviewMove(
  GameState game,
  int index, {
  required PositionEval evalBefore,
  required PositionEval evalAfter,
}) {
  final played = game.moves[index];
  final positionBefore = game.history[index];
  final positionAfter = game.history[index + 1];
  final mover = played.side;

  final before = evalBefore.pawnsFor(mover, mover);
  final after = evalAfter.pawnsFor(mover, mover.opposite);
  final loss = math.max(0.0, before - after);

  final quality = _classify(
    positionBefore: positionBefore,
    positionAfter: positionAfter,
    played: played,
    previous: index > 0 ? game.moves[index - 1] : null,
    evalBefore: evalBefore,
    before: before,
    after: after,
    loss: loss,
  );

  return MoveReview(
    index: index,
    move: played,
    before: before,
    after: after,
    loss: loss,
    accuracy: moveAccuracy(before, after),
    quality: quality,
  );
}

MoveQuality? _classify({
  required Position positionBefore,
  required Position positionAfter,
  required PlayedMove played,
  required PlayedMove? previous,
  required PositionEval evalBefore,
  required double before,
  required double after,
  required double loss,
}) {
  if (loss > ReviewRules.blunder) return MoveQuality.blunder;
  if (after < ReviewRules.stillWinning) {
    if (loss > ReviewRules.mistake) return MoveQuality.mistake;
    if (loss > ReviewRules.inaccuracy) return MoveQuality.inaccuracy;
  }

  // `!` / `!!`: the top move when the alternative was clearly worse, and
  // finding it took thought: not escaping check, not simply recapturing.
  final isRecapture =
      played.captured != null &&
      previous?.captured != null &&
      (played.move as NormalMove).to == (previous!.move as NormalMove).to;
  if (positionBefore.isCheck || isRecapture) return null;
  final best = evalBefore.bestMove;
  final second = evalBefore.secondScore;
  if (best == null || second == null) return null;
  final bestMove = Move.parse(best);
  final isBest = bestMove is NormalMove && positionBefore.normalizeMove(bestMove) == played.move;
  if (!isBest) return null;
  final gap = cappedPawns(evalBefore.score) - cappedPawns(second);
  if (gap < ReviewRules.onlyMoveGap) return null;

  if (_isSacrifice(positionAfter, played)) return MoveQuality.brilliant;
  return before.abs() < ReviewRules.balanced ? MoveQuality.best : null;
}

/// The move puts material at risk: the moved piece, less whatever it just
/// captured, is worth [ReviewRules.sacrificeValue]+ and can be taken, either
/// because it is undefended or because a cheaper piece attacks it. (A king
/// can only take an undefended piece.)
bool _isSacrifice(Position after, PlayedMove played) {
  final move = played.move;
  if (move is! NormalMove) return false;
  final piece = after.board.pieceAt(move.to);
  if (piece == null) return false; // Castling moves the king elsewhere.
  final value = pieceValue(piece.role);
  final captured = played.captured == null ? 0 : pieceValue(played.captured!);
  if (value - captured < ReviewRules.sacrificeValue) return false;

  final attackers = after.board.attacksTo(move.to, piece.color.opposite);
  if (attackers.isEmpty) return false;
  final defenders = after.board.attacksTo(move.to, piece.color);
  if (defenders.isEmpty) return true;
  final cheapest = [
    for (final square in attackers.squares)
      if (after.board.pieceAt(square)!.role != Role.king)
        pieceValue(after.board.pieceAt(square)!.role),
  ];
  return cheapest.isNotEmpty && cheapest.reduce(math.min) < value;
}

/// Winning chances (0–100) for a side at [pawns], as Lichess computes them.
double winPercent(double pawns) {
  final cp = pawns * 100;
  return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * cp)) - 1);
}

/// Lichess's per-move accuracy, from the mover's evaluations [before] and
/// [after] the move (pawns).
double moveAccuracy(double before, double after) =>
    accuracyFromWinPercents(winPercent(before), winPercent(after));

/// Lichess's accuracy (0–100) for a move that took the mover's winning
/// chances from [before] to [after]: 100 when they didn't drop, plus a
/// 1-point allowance for imperfect analysis (lila `AccuracyPercent`).
double accuracyFromWinPercents(double before, double after) {
  if (after >= before) return 100;
  final raw =
      103.1668100711649 * math.exp(-0.04354415386753951 * (before - after)) - 3.166924740191411;
  return (raw + 1).clamp(0.0, 100.0);
}
