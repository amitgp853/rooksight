import 'package:dartchess/dartchess.dart';

import 'game_result.dart';

/// Game-level rules that `dartchess` leaves to the caller: it knows single
/// positions (checkmate, stalemate, insufficient material), but not history.
abstract final class GameRules {
  /// Halfmoves without a capture or pawn move that end the game (50 moves each).
  static const fiftyMoveHalfmoves = 100;

  /// The result after the last position in [history], or null if play goes on.
  ///
  /// [history] holds every position of the game, starting position first.
  /// Draws by repetition and the 50-move rule are applied automatically, as
  /// on most chess apps (no claim needed).
  static GameResult? resultOf(List<Position> history) {
    final position = history.last;
    if (position.isCheckmate) {
      return GameResult.win(position.turn.opposite, GameEndReason.checkmate);
    }
    if (position.isStalemate) return const GameResult.draw(GameEndReason.stalemate);
    if (position.isInsufficientMaterial) {
      return const GameResult.draw(GameEndReason.insufficientMaterial);
    }
    if (isThreefoldRepetition(history)) {
      return const GameResult.draw(GameEndReason.threefoldRepetition);
    }
    if (position.halfmoves >= fiftyMoveHalfmoves) {
      return const GameResult.draw(GameEndReason.fiftyMoveRule);
    }
    return null;
  }

  /// Whether the last position in [history] has occurred at least three times.
  static bool isThreefoldRepetition(List<Position> history) {
    final key = repetitionKey(history.last);
    return history.where((p) => repetitionKey(p) == key).length >= 3;
  }

  /// Identifies a position for repetition: pieces, side to move, castling
  /// rights and en passant square, but not the move counters.
  ///
  /// `dartchess` only writes the en passant square into the FEN when the
  /// capture is actually legal, which is what the repetition rule requires.
  static String repetitionKey(Position position) => position.fen.split(' ').take(4).join(' ');

  /// The result when [loser] runs out of time: a loss, unless the opponent
  /// has no way to checkmate, in which case it is a draw (FIDE 6.9).
  static GameResult onTimeout(Position position, Side loser) {
    return position.hasInsufficientMaterial(loser.opposite)
        ? const GameResult.draw(GameEndReason.timeout)
        : GameResult.win(loser.opposite, GameEndReason.timeout);
  }
}
