// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/chess/move_check.dart';
import '../../play/domain/game_state.dart' show pieceValue;
import '../../play/widgets/result_copy.dart' show moveLabel;
import 'game_analysis.dart';
import 'moment_text.dart';
import 'move_review.dart';

/// What Stockfish and the rules say about one key moment: the facts the AI
/// explains, and the limits its claims are checked against. All computed on
/// the phone; the AI only puts them into words.
@immutable
class MomentFacts {
  const MomentFacts({
    required this.index,
    required this.move,
    required this.byPlayer,
    required this.quality,
    required this.evalBefore,
    required this.evalAfter,
    required this.bestMove,
    required this.bestLine,
    required this.replyLine,
    required this.materialAfterBestLine,
    required this.materialAfterReplyLine,
    required this.hanging,
    required this.mateAvailable,
    required this.mateAllowed,
    required this.phase,
    required this.allowedMoves,
  });

  final int index;

  /// `22…f6`.
  final String move;
  final bool byPlayer;
  final MoveQuality? quality;

  /// Pawns, from the mover's side.
  final double evalBefore;
  final double evalAfter;

  /// `22…Nxb5`, when Stockfish preferred another move.
  final String? bestMove;

  /// Stockfish's best line instead of the move, in SAN.
  final List<String> bestLine;

  /// What the opponent can do after the move actually played: Stockfish's
  /// best line from there. This is usually *why* a move was bad.
  final List<String> replyLine;

  /// Material change for the mover (pawns) at the end of each line.
  final int materialAfterBestLine;
  final int materialAfterReplyLine;

  /// The mover's pieces left en prise after the move, e.g. `knight on e5`.
  final List<String> hanging;

  /// The mover had a forced mate in this many moves (before the move).
  final int? mateAvailable;

  /// After the move, the opponent has a forced mate in this many moves.
  final int? mateAllowed;

  /// `opening`, `middlegame` or `endgame`.
  final String phase;

  /// Moves the AI may name for this moment (SAN without `+`/`#`).
  final Set<String> allowedMoves;

  /// Whether a mention of mate is backed by Stockfish.
  bool get mateIsReal =>
      mateAvailable != null ||
      mateAllowed != null ||
      move.endsWith('#') ||
      bestLine.any((san) => san.endsWith('#')) ||
      replyLine.any((san) => san.endsWith('#'));

  /// The biggest material swing Stockfish's lines show, in pawns, counting
  /// hanging pieces as swings of their value.
  int get biggestSwing => [
    materialAfterBestLine.abs(),
    materialAfterReplyLine.abs(),
    ...hanging.map((h) => pieceValue(_roleNamed(h.split(' ').first))),
  ].fold(0, math.max);

  /// Whether the move played was Stockfish's first choice.
  bool get playedBest =>
      bestLine.isNotEmpty && move.replaceFirst(RegExp(r'^\d+(?:\.\s*|…)'), '') == bestLine.first;

  /// The facts as the model gets them. Only what adds something goes in:
  /// when the move was Stockfish's choice, its best line is just the move
  /// plus [replyLine], and a material change of zero is left out (the
  /// prompts say so), as are empty lists and absent mates.
  Map<String, Object?> toJson() => {
    'id': index,
    'move': move,
    'by': byPlayer ? 'player' : 'opponent',
    'verdict': quality?.label,
    'phase': phase,
    'eval_before': _round(evalBefore),
    'eval_after': _round(evalAfter),
    'best_move': ?bestMove,
    if (bestLine.isNotEmpty && !playedBest) 'best_line': bestLine.join(' '),
    if (replyLine.isNotEmpty) 'what_the_move_allowed': replyLine.join(' '),
    if (materialAfterBestLine != 0 && !playedBest) 'best_line_material': materialAfterBestLine,
    if (materialAfterReplyLine != 0) 'allowed_material': materialAfterReplyLine,
    if (hanging.isNotEmpty) 'pieces_left_hanging': hanging,
    'mate_in_available': ?mateAvailable,
    'mate_in_allowed_for_opponent': ?mateAllowed,
  };

  static double _round(double pawns) => double.parse(pawns.toStringAsFixed(2));
}

/// The facts for [moment] of [analysis].
MomentFacts factsFor(GameAnalysis analysis, MoveReview moment, {required Side player}) {
  final game = analysis.game;
  final i = moment.index;
  final before = game.history[i];
  final after = game.history[i + 1];
  final mover = moment.side;
  final evalBefore = analysis.evals[i];
  final evalAfter = analysis.evals[i + 1];

  final best = playLine(before, evalBefore.bestLine.take(6));
  final reply = playLine(after, evalAfter.bestLine.take(6));
  final bestSans = sanLine(before, evalBefore.bestLine.take(6));
  final replySans = sanLine(after, evalAfter.bestLine.take(6));

  final start = materialBalance(before, mover);
  final mateBefore = evalBefore.score.mate;
  final mateAfter = evalAfter.score.mate;

  return MomentFacts(
    index: i,
    move: moveLabel(game, i),
    byPlayer: mover == player,
    quality: moment.quality,
    evalBefore: moment.before,
    evalAfter: moment.after,
    bestMove: moment.quality != null && moment.quality!.isError ? bestMoveLabel(analysis, i) : null,
    bestLine: bestSans,
    replyLine: replySans,
    materialAfterBestLine: materialBalance(best.positions.last, mover) - start,
    materialAfterReplyLine: materialBalance(reply.positions.last, mover) - start,
    hanging: hangingPieces(after, mover),
    mateAvailable: mateBefore != null && mateBefore > 0 ? mateBefore : null,
    // Scores after the move are from the opponent's side.
    mateAllowed: mateAfter != null && mateAfter > 0 ? mateAfter : null,
    phase: gamePhase(before),
    allowedMoves: {
      ...MoveCheck.legalSans(before),
      ...MoveCheck.legalSans(after),
      for (final san in [...bestSans, ...replySans]) MoveCheck.strip(san),
    },
  );
}

/// [side]'s material minus the opponent's, in pawns.
int materialBalance(Position position, Side side) {
  var total = 0;
  for (final role in Role.values) {
    total += pieceValue(role) * position.board.piecesOf(side, role).size;
    total -= pieceValue(role) * position.board.piecesOf(side.opposite, role).size;
  }
  return total;
}

/// [side]'s pieces (worth 3+) that the opponent can take for free or with a
/// cheaper piece, e.g. `knight on e5`. A king only takes undefended pieces.
List<String> hangingPieces(Position position, Side side) {
  final result = <String>[];
  for (final square in position.board.bySide(side).squares) {
    final piece = position.board.pieceAt(square)!;
    final value = pieceValue(piece.role);
    if (value < 3) continue;
    final attackers = position.board.attacksTo(square, side.opposite);
    if (attackers.isEmpty) continue;
    final defended = position.board.attacksTo(square, side).isNotEmpty;
    final cheaper = attackers.squares.any((sq) {
      final attacker = position.board.pieceAt(sq)!.role;
      return attacker != Role.king && pieceValue(attacker) < value;
    });
    if (!defended || cheaper) result.add('${_roleName(piece.role)} on ${square.name}');
  }
  return result;
}

/// Opening while most pieces are home early on; endgame once little
/// material is left; middlegame otherwise.
String gamePhase(Position position) {
  var pieces = 0;
  for (final role in [Role.knight, Role.bishop, Role.rook, Role.queen]) {
    pieces += pieceValue(role) * position.board.byRole(role).size;
  }
  if (pieces <= 26) return 'endgame';
  if (position.fullmoves <= 10) return 'opening';
  return 'middlegame';
}

String _roleName(Role role) => switch (role) {
  Role.pawn => 'pawn',
  Role.knight => 'knight',
  Role.bishop => 'bishop',
  Role.rook => 'rook',
  Role.queen => 'queen',
  Role.king => 'king',
};

Role _roleNamed(String name) => Role.values.firstWhere((r) => _roleName(r) == name);
