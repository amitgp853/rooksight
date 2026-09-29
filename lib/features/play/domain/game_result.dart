import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// Why a game ended.
enum GameEndReason {
  checkmate,
  stalemate,
  threefoldRepetition,
  fiftyMoveRule,
  insufficientMaterial,
  resignation,
  timeout,
  agreement,
}

/// The outcome of a finished game. [winner] is null for a draw.
@immutable
class GameResult {
  const GameResult.win(Side this.winner, this.reason);

  const GameResult.draw(this.reason) : winner = null;

  final Side? winner;
  final GameEndReason reason;

  bool get isDraw => winner == null;

  /// PGN result tag: `1-0`, `0-1` or `1/2-1/2`.
  String get pgn => switch (winner) {
    Side.white => '1-0',
    Side.black => '0-1',
    null => '1/2-1/2',
  };

  @override
  bool operator ==(Object other) =>
      other is GameResult && other.winner == winner && other.reason == reason;

  @override
  int get hashCode => Object.hash(winner, reason);

  @override
  String toString() => 'GameResult($pgn, ${reason.name})';
}
