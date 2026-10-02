// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../engine/uci.dart';

/// Stockfish's verdict on one position of a game: its best line and, when
/// there was one, the second-best move's score. Stored raw (scores from the
/// side to move) so move marks can be re-derived if the thresholds change.
@immutable
class PositionEval {
  const PositionEval({
    required this.score,
    required this.bestLine,
    this.secondScore,
    this.depth = 0,
  });

  /// A finished position: checkmate (the side to move is mated) or a draw.
  factory PositionEval.terminal(Position position) => PositionEval(
    score: position.isCheckmate ? const EngineScore.mate(0) : const EngineScore.centipawns(0),
    bestLine: const [],
  );

  /// From the side to move's point of view.
  final EngineScore score;

  /// Best line in UCI notation; empty when there are no legal moves.
  final List<String> bestLine;

  /// Score of the second-best move, if the position had more than one.
  final EngineScore? secondScore;
  final int depth;

  String? get bestMove => bestLine.isEmpty ? null : bestLine.first;

  /// Score in pawns from [side]'s point of view, capped at ±10 (mates count
  /// as ±10), given that [toMove] is to move in this position.
  double pawnsFor(Side side, Side toMove) {
    final pawns = cappedPawns(score);
    return side == toMove ? pawns : -pawns;
  }

  Map<String, Object?> toJson() => {
    'cp': score.centipawns,
    'mate': score.mate,
    'pv': bestLine,
    if (secondScore != null) ...{'cp2': secondScore!.centipawns, 'mate2': secondScore!.mate},
    'd': depth,
  };

  factory PositionEval.fromJson(Map<String, Object?> json) {
    EngineScore? score(Object? cp, Object? mate) => mate is int
        ? EngineScore.mate(mate)
        : cp is int
        ? EngineScore.centipawns(cp)
        : null;
    return PositionEval(
      score: score(json['cp'], json['mate']) ?? const EngineScore.centipawns(0),
      bestLine: [...?(json['pv'] as List<Object?>?)?.whereType<String>()],
      secondScore: score(json['cp2'], json['mate2']),
      depth: (json['d'] as int?) ?? 0,
    );
  }
}

/// Evaluations are capped at ±10 pawns: beyond that a position is simply
/// won or lost, and differences there aren't meaningful. `mate 0` (already
/// mated) counts as lost.
const evalCap = 10.0;

double cappedPawns(EngineScore score) {
  final mate = score.mate;
  if (mate != null) return mate > 0 ? evalCap : -evalCap;
  return (score.centipawns! / 100).clamp(-evalCap, evalCap);
}
