// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';

/// Checks that moves a language model writes are real moves, so an AI
/// explanation never teaches a move that can't be played.
abstract final class MoveCheck {
  /// Moves in text: piece moves (`Nf3`, `Rxd8+`), pawn captures (`exd5`),
  /// promotions (`b8=Q`), castling, and pawn pushes written with a move
  /// number (`23. d5`, `23…d5`). A bare square such as "d5" is a square.
  static final _pieceOrCapture = RegExp(
    r'\b(O-O-O|O-O|[KQRBN][a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?|[a-h]x[a-h][1-8](?:=[QRBN])?|[a-h][18]=[QRBN])[+#]?',
  );
  static final _numberedPawnPush = RegExp(r'\b\d+\s*(?:\.\.\.|…|\.)\s*([a-h][1-8])(?![\w=])');

  /// The moves [text] mentions, in SAN without `+`/`#`.
  static Set<String> movesIn(String text) => {
    for (final match in _pieceOrCapture.allMatches(text)) match[1]!,
    for (final match in _numberedPawnPush.allMatches(text)) match[1]!,
  };

  /// Every legal move in [position], in SAN without `+`/`#`.
  static Set<String> legalSans(Position position) {
    final sans = <String>{};
    for (final MapEntry(key: from, value: targets) in position.legalMoves.entries) {
      for (final to in targets.squares) {
        final isPromotion =
            position.board.pieceAt(from)?.role == Role.pawn &&
            (to.rank == Rank.first || to.rank == Rank.eighth);
        for (final role
            in isPromotion ? [Role.queen, Role.rook, Role.bishop, Role.knight] : [null]) {
          final move = NormalMove(from: from, to: to, promotion: role);
          if (position.isLegal(move)) sans.add(strip(position.makeSan(move).$2));
        }
      }
    }
    return sans;
  }

  /// SAN without check and mate marks.
  static String strip(String san) => san.replaceAll(RegExp(r'[+#]'), '');

  /// [text] with every sentence that mentions a move outside [allowed]
  /// removed. Returns '' if nothing survives.
  static String keepChecked(String text, Set<String> allowed) {
    final sentences = text.trim().split(RegExp(r'(?<=[.!?])\s+'));
    return sentences
        .where((sentence) => movesIn(sentence).every(allowed.contains))
        .join(' ')
        .trim();
  }
}
