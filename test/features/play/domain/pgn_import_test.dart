// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/features/play/domain/pgn_import.dart';

void main() {
  test('replays the main line', () {
    final game = gameFromPgn('[Result "0-1"]\n\n1. f3 e5 2. g4 Qh4# 0-1');
    expect(game.moves.map((m) => m.san), ['f3', 'e5', 'g4', 'Qh4#']);
    expect(game.position.isCheckmate, isTrue);
  });

  test('starts from the FEN header', () {
    final game = gameFromPgn('[SetUp "1"]\n[FEN "4k3/8/8/8/8/8/4P3/4K3 w - - 0 40"]\n\n40. e4 *');
    expect(game.history.first.fullmoves, 40);
    expect(game.position.board.pieceAt(Square.e4)?.role, Role.pawn);
  });

  test('stops at the first illegal move', () {
    final game = gameFromPgn('1. e4 e5 2. Ke3 Nc6 *');
    expect(game.moves.map((m) => m.san), ['e4', 'e5']);
  });
}
