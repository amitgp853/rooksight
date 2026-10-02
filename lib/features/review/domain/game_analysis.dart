// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

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

  /// Moments shown besides the blunders, which are never left out.
  static const maxKeyMoments = 10;
  static const maxGoodMoments = 2;

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

  /// How much [move] changed the game: the winning chances (0–100) its mover
  /// gave away. A blunder from +1 to −3 costs far more than one from −6 to
  /// −9, even though both lose three pawns.
  static double impact(MoveReview move) =>
      math.max(0, winPercent(move.before) - winPercent(move.after));

  /// The moments worth explaining to [player], the ones that changed the
  /// game most first:
  /// * every blunder, by either side (the opponent's were chances to
  ///   punish), however many there are;
  /// * then, up to [maxKeyMoments] in all, the player's mistakes and
  ///   inaccuracies and the opponent's mistakes, costliest first;
  /// * then, if there's room, up to [maxGoodMoments] of the player's best
  ///   finds (brilliant first).
  List<MoveReview> keyMoments(Side player) {
    final marked = moves.where((m) => m.quality != null).toList();
    int byImpact(MoveReview a, MoveReview b) {
      final order = impact(b).compareTo(impact(a));
      return order != 0 ? order : a.index.compareTo(b.index);
    }

    final blunders = marked.where((m) => m.quality == MoveQuality.blunder).toList()..sort(byImpact);
    final errors =
        marked
            .where(
              (m) => m.side == player
                  ? m.quality == MoveQuality.mistake || m.quality == MoveQuality.inaccuracy
                  : m.quality == MoveQuality.mistake,
            )
            .toList()
          ..sort(byImpact);
    final good = marked.where((m) => m.side == player && !m.quality!.isError).toList()
      ..sort(
        (a, b) => a.quality!.index != b.quality!.index
            ? a.quality!.index.compareTo(b.quality!.index)
            : a.index.compareTo(b.index),
      );

    final room = math.max(0, maxKeyMoments - blunders.length);
    final chosen = [...blunders, ...errors.take(room)]..sort(byImpact);
    final goodRoom = math.min(maxGoodMoments, maxKeyMoments - chosen.length);
    return [...chosen, if (goodRoom > 0) ...good.take(goodRoom)];
  }
}
