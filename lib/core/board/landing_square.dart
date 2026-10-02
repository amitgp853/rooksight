// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';

/// Where [move]'s piece ends up in [before]: the king's square when
/// castling, which `dartchess` stores as king-takes-rook. Marks such as the
/// quality badge go there.
Square? landingSquare(Position before, Move move) {
  if (move is! NormalMove) return null;
  final piece = before.board.pieceAt(move.from);
  final target = before.board.pieceAt(move.to);
  final isCastle =
      piece?.role == Role.king && target?.role == Role.rook && target?.color == piece?.color;
  if (!isCastle) return move.to;
  final kingSide = move.to.file > move.from.file;
  return Square.fromCoords(kingSide ? File.g : File.c, move.from.rank);
}
