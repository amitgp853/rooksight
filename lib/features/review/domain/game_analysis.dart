import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../play/domain/game_state.dart';
import 'move_review.dart';
import 'position_eval.dart';

/// A game with Stockfish's evaluations of its positions. While the analysis
/// runs, [evals] covers only the first positions; everything derived from it
/// covers what is known so far.
@immutable
class GameAnalysis {
  GameAnalysis(this.game, List<PositionEval> evals)
    : evals = List.unmodifiable(evals),
      moves = List.unmodifiable([
        for (var i = 0; i + 1 < evals.length && i < game.moves.length; i++)
          reviewMove(game, i, evalBefore: evals[i], evalAfter: evals[i + 1]),
      ]);

  final GameState game;

  /// One per position of [game], starting position first.
  final List<PositionEval> evals;

  /// One per move whose before and after positions are both evaluated.
  final List<MoveReview> moves;

  static const maxKeyMoments = 8;
  static const maxErrorMoments = 6;
  static const maxGoodMoments = 2;

  /// The opponent's worst mistakes: chances the player had to punish.
  static const maxOpponentMoments = 2;

  bool get isComplete => evals.length == game.history.length;

  /// Evaluation of position [ply] in pawns for White, capped at ±10.
  double? whiteEval(int ply) {
    if (ply >= evals.length) return null;
    return evals[ply].pawnsFor(Side.white, game.history[ply].turn);
  }

  /// [side]'s accuracy for the game (0–100), computed as Lichess does, or
  /// null before any of their moves is evaluated.
  ///
  /// A plain average of move accuracies hides blunders (sixty good moves
  /// outweigh a few terrible ones), so Lichess averages two means:
  /// * a weighted mean, where each move counts by how volatile the game was
  ///   around it (the standard deviation of winning chances in a window), so
  ///   moves in sharp positions matter more;
  /// * a harmonic mean, which low scores pull down hard.
  ///
  /// See lila's `AccuracyPercent.gameAccuracy`.
  double? accuracy(Side side) {
    // Evaluated positions of the game (never more than it has).
    final positions = math.min(evals.length, game.history.length);
    if (positions < 2) return null;
    // White's winning chances in every evaluated position.
    final wins = [for (var i = 0; i < positions; i++) winPercent(whiteEval(i)!)];

    final window = ((positions - 1) ~/ 10).clamp(2, 8);
    final windows = [
      for (var i = 0; i < math.min(window, positions) - 2; i++) wins.take(window).toList(),
      for (var i = 0; i + window <= positions; i++) wins.sublist(i, i + window),
    ];

    final accuracies = <double>[];
    final weights = <double>[];
    for (var i = 0; i + 1 < positions && i < windows.length; i++) {
      if (game.moves[i].side != side) continue;
      // Winning chances from the mover's side, before and after the move.
      final (before, after) = side == Side.white
          ? (wins[i], wins[i + 1])
          : (100 - wins[i], 100 - wins[i + 1]);
      accuracies.add(accuracyFromWinPercents(before, after));
      weights.add(_standardDeviation(windows[i]).clamp(0.5, 12.0));
    }
    if (accuracies.isEmpty) return null;

    var weightedSum = 0.0;
    var weightTotal = 0.0;
    for (var i = 0; i < accuracies.length; i++) {
      weightedSum += accuracies[i] * weights[i];
      weightTotal += weights[i];
    }
    final weighted = weightedSum / weightTotal;
    // lila counts a score under 1 as 1, so one 0 doesn't zero the mean.
    final harmonic = accuracies.length / accuracies.fold(0.0, (sum, a) => sum + 1 / math.max(1, a));
    return (weighted + harmonic) / 2;
  }

  static double _standardDeviation(List<double> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.fold(0.0, (sum, v) => sum + (v - mean) * (v - mean)) / values.length;
    return math.sqrt(variance);
  }

  /// How many of [side]'s moves got each mark.
  Map<MoveQuality, int> counts(Side side) => {
    for (final quality in MoveQuality.values)
      quality: moves.where((m) => m.side == side && m.quality == quality).length,
  };

  /// The moments worth explaining to [player], in game order: their costliest
  /// errors (worst first, up to [maxErrorMoments]), a couple of their best
  /// finds, and the opponent's worst slips (mistakes or blunders), at most
  /// [maxKeyMoments] in all.
  List<MoveReview> keyMoments(Side player) {
    List<MoveReview> marked(Side side) =>
        moves.where((m) => m.side == side && m.quality != null).toList();
    int byLoss(MoveReview a, MoveReview b) => b.loss.compareTo(a.loss);

    final own = marked(player);
    final errors = own.where((m) => m.quality!.isError).toList()..sort(byLoss);
    final good = own.where((m) => !m.quality!.isError).toList()
      // Brilliant first, then earlier moves.
      ..sort((a, b) => a.quality!.index.compareTo(b.quality!.index));
    final opponent =
        marked(player.opposite)
            .where((m) => m.quality == MoveQuality.mistake || m.quality == MoveQuality.blunder)
            .toList()
          ..sort(byLoss);

    final chosen = [
      ...errors.take(maxErrorMoments),
      ...good.take(maxGoodMoments),
      ...opponent.take(maxOpponentMoments),
    ]..sort((a, b) => a.index.compareTo(b.index));
    return chosen.take(maxKeyMoments).toList();
  }
}
