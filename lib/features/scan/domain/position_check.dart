// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'board_setup.dart';

/// Why a position can't be analysed, and the squares involved (to mark on
/// the board).
@immutable
class PositionProblem {
  const PositionProblem(this.message, {this.squares = const {}, this.cause});

  /// One sentence for the player, e.g. "Each side needs exactly one king.
  /// White has two, on e1 and g1."
  final String message;
  final Set<Square> squares;
  final PositionProblemCause? cause;
}

enum PositionProblemCause { kings, backRankPawns, tooManyPieces, tooManyPawns, wrongCheck, other }

/// The first rule [setup] breaks, or null when it is a legal position.
///
/// The rules, in order (design: Scan + Analysis spec, "Legal-position
/// checks"): exactly one king per side; no pawns on the first or last rank;
/// at most 16 pieces (and 8 pawns) a side; the side not to move isn't in
/// check. Anything else dartchess rejects comes last.
PositionProblem? checkPosition(BoardSetup setup) {
  final board = setup.board;

  for (final side in Side.values) {
    final kings = board.piecesOf(side, Role.king).squares.toList();
    if (kings.length != 1) {
      final name = _sideName(side);
      return PositionProblem(
        kings.isEmpty
            ? '$name has no king. Each side needs exactly one.'
            : 'Each side needs exactly one king. $name has ${_count(kings.length)}, '
                  'on ${_list(kings)}.',
        squares: kings.toSet(),
        cause: PositionProblemCause.kings,
      );
    }
  }

  final backRank = [
    for (final side in Side.values)
      ...board
          .piecesOf(side, Role.pawn)
          .squares
          .where((s) => s.rank == Rank.first || s.rank == Rank.eighth),
  ];
  if (backRank.isNotEmpty) {
    return PositionProblem(
      'Pawns can’t stand on the first or last rank: '
      '${backRank.length == 1 ? 'there’s one on' : 'there are pawns on'} ${_list(backRank)}.',
      squares: backRank.toSet(),
      cause: PositionProblemCause.backRankPawns,
    );
  }

  for (final side in Side.values) {
    final count = board.bySide(side).size;
    if (count > 16) {
      return PositionProblem(
        '${_sideName(side)} has $count pieces. A side can have at most 16.',
        cause: PositionProblemCause.tooManyPieces,
      );
    }
    final pawns = board.piecesOf(side, Role.pawn).size;
    if (pawns > 8) {
      return PositionProblem(
        '${_sideName(side)} has $pawns pawns. A side can have at most 8.',
        squares: board.piecesOf(side, Role.pawn).squares.toSet(),
        cause: PositionProblemCause.tooManyPawns,
      );
    }
  }

  final waiting = setup.turn.opposite;
  final king = board.kingOf(waiting)!;
  final checkers = board.attacksTo(king, setup.turn);
  if (checkers.isNotEmpty) {
    return PositionProblem(
      '${_sideName(waiting)} is in check, so it can’t be ${_sideName(setup.turn)}’s move. '
      'Switch the side to move, or fix the position.',
      squares: {king, ...checkers.squares},
      cause: PositionProblemCause.wrongCheck,
    );
  }

  try {
    Chess.fromSetup(Setup.parseFen(setup.fen));
  } on PositionSetupException {
    return const PositionProblem(
      'This check can’t happen in a real game. Look at the pieces giving check.',
      cause: PositionProblemCause.other,
    );
  }
  return null;
}

/// The legal position [setup] describes. Only call once [checkPosition] is
/// null.
Position positionOf(BoardSetup setup) => Chess.fromSetup(Setup.parseFen(setup.fen));

String _sideName(Side side) => side == Side.white ? 'White' : 'Black';

String _count(int n) => switch (n) {
  2 => 'two',
  3 => 'three',
  4 => 'four',
  _ => '$n',
};

/// `e1`, `e1 and g1`, `a2, b2 and c2`.
String _list(List<Square> squares) {
  final names = [for (final s in squares) s.name];
  if (names.length <= 1) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}
