// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'chess_engine.dart';
import 'uci.dart';

/// One Stockfish strength level offered in Play setup (400–3000, step 200).
///
/// From 1400 up, Stockfish limits itself (`UCI_LimitStrength` + `UCI_Elo`).
/// Its floor is about 1320, so 400–1200 are weakened by hand, to play like a
/// person at that level rather than a slightly worse engine:
///
/// * a shallow search, so it can't see that a piece is left hanging;
/// * a choice among many candidate moves, weighted by how much worse each is
///   than the best (`weight = e^(−loss / tolerance)`), so weaker levels often
///   play moves that lose material;
/// * a small chance of a completely random legal move.
///
/// The numbers are tuned by feel and all live in [EloLevel.all].
@immutable
class EloLevel {
  const EloLevel._manual({
    required this.elo,
    required int this.depth,
    required int this.toleranceCp,
    required this.randomMoveChance,
  }) : moveTime = null,
       usesStockfishElo = false;

  const EloLevel._stockfish({required this.elo, required Duration this.moveTime})
    : depth = null,
      toleranceCp = null,
      randomMoveChance = 0,
      usesStockfishElo = true;

  final int elo;

  /// True from 1400 up, where Stockfish's own `UCI_Elo` does the work.
  final bool usesStockfishElo;

  /// Search depth in plies (hand-weakened levels).
  final int? depth;

  /// Search time (Stockfish-Elo levels).
  final Duration? moveTime;

  /// How forgiving the move choice is, in centipawns: a move this much worse
  /// than the best is picked e (~2.7) times less often than the best.
  final int? toleranceCp;

  /// Chance (0–1) of playing any legal move at random.
  final double randomMoveChance;

  /// Candidate lines searched by hand-weakened levels.
  static const candidates = 12;

  static const minElo = 400;
  static const maxElo = 3000;
  static const step = 200;

  static const all = [
    EloLevel._manual(elo: 400, depth: 1, toleranceCp: 300, randomMoveChance: 0.15),
    EloLevel._manual(elo: 600, depth: 2, toleranceCp: 200, randomMoveChance: 0.08),
    EloLevel._manual(elo: 800, depth: 3, toleranceCp: 130, randomMoveChance: 0.04),
    EloLevel._manual(elo: 1000, depth: 4, toleranceCp: 80, randomMoveChance: 0.02),
    EloLevel._manual(elo: 1200, depth: 6, toleranceCp: 45, randomMoveChance: 0.005),
    EloLevel._stockfish(elo: 1400, moveTime: Duration(milliseconds: 500)),
    EloLevel._stockfish(elo: 1600, moveTime: Duration(milliseconds: 500)),
    EloLevel._stockfish(elo: 1800, moveTime: Duration(milliseconds: 500)),
    EloLevel._stockfish(elo: 2000, moveTime: Duration(milliseconds: 1000)),
    EloLevel._stockfish(elo: 2200, moveTime: Duration(milliseconds: 1000)),
    EloLevel._stockfish(elo: 2400, moveTime: Duration(milliseconds: 1000)),
    EloLevel._stockfish(elo: 2600, moveTime: Duration(milliseconds: 1500)),
    EloLevel._stockfish(elo: 2800, moveTime: Duration(milliseconds: 1500)),
    EloLevel._stockfish(elo: 3000, moveTime: Duration(milliseconds: 1500)),
  ];

  /// The level for [elo], rounded to the nearest step and clamped to range.
  static EloLevel of(int elo) {
    final clamped = elo.clamp(minElo, maxElo);
    final index = ((clamped - minElo) / step).round();
    return all[index];
  }

  /// Name shown in Play setup.
  String get label => switch (elo) {
    <= 800 => 'Beginner',
    <= 1200 => 'Casual',
    <= 1800 => 'Club player',
    <= 2200 => 'Strong club',
    <= 2600 => 'Master',
    _ => 'Super-GM',
  };

  /// Hand-weakened levels search at full skill so the scores are honest; the
  /// weakening happens in [chooseMove].
  SearchLimits get searchLimits => usesStockfishElo
      ? SearchLimits(moveTime: moveTime, limitElo: elo)
      : SearchLimits(depth: depth, lines: candidates);

  /// Picks the move to play, in UCI notation, or null when there is none.
  ///
  /// [lines] are the engine's candidates, best first; [legalMoves] are all
  /// legal moves in UCI notation, used for the occasional random move.
  String? chooseMove(List<EngineLine> lines, List<String> legalMoves, Random random) {
    if (lines.isEmpty) return null;
    final tolerance = toleranceCp;
    if (usesStockfishElo || tolerance == null) return lines.first.move;

    if (legalMoves.isNotEmpty && random.nextDouble() < randomMoveChance) {
      return legalMoves[random.nextInt(legalMoves.length)];
    }

    // Scores are all from the engine's side, so loss = best − this.
    final best = _centipawns(lines.first.score);
    final weights = [
      for (final line in lines) exp(-max(0, best - _centipawns(line.score)) / tolerance),
    ];
    var roll = random.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < lines.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return lines[i].move;
    }
    return lines.last.move;
  }

  /// Mates count as ±100 pawns, so missing a mate is a huge loss.
  static double _centipawns(EngineScore score) => score.pawns * 100;

  @override
  String toString() => 'EloLevel($elo)';
}

/// Full-strength search used for hints (and, later, draw-offer decisions).
const fullStrengthLimits = SearchLimits(moveTime: Duration(milliseconds: 800));
