import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../review/domain/move_review.dart';

/// A move from one of the player's games that a coach answer points to:
/// shown as a small card that opens the review there.
@immutable
class CoachMove {
  const CoachMove({
    required this.gameId,
    required this.index,
    required this.label,
    required this.fen,
    required this.lastMove,
    required this.orientation,
    required this.opponent,
    required this.playedAt,
    this.quality,
    this.best,
  });

  final int gameId;

  /// Index into the game's moves.
  final int index;

  /// `23. Nxd5`.
  final String label;
  final MoveQuality? quality;

  /// Stockfish's move instead, in SAN (`Rd1`).
  final String? best;

  /// The position after the move.
  final String fen;
  final Move lastMove;

  /// The player's side, at the bottom of the board.
  final Side orientation;

  /// `Stockfish 1600`, or the Chess.com opponent.
  final String opponent;
  final DateTime playedAt;
}
