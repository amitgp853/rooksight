import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../domain/game_result.dart';
import '../domain/game_session.dart';
import '../domain/game_state.dart';

/// Win, draw or loss from the player's side; sets the overline colour.
enum ResultTone { win, draw, loss }

/// The text on the result sheet (`design/source/ResultCards.dc.html`).
@immutable
class ResultCopy {
  const ResultCopy({
    required this.overline,
    required this.title,
    required this.reason,
    required this.score,
    required this.tone,
  });

  /// Describes how [session]'s finished game ended.
  factory ResultCopy.of(GameSession session) {
    final game = session.game;
    final result = game.result!;
    final player = session.config.playerSide;
    final tone = result.isDraw
        ? ResultTone.draw
        : result.winner == player
        ? ResultTone.win
        : ResultTone.loss;
    final moveNumber = game.position.fullmoves;
    final lastMove = game.moves.isEmpty ? '' : moveLabel(game, game.moves.length - 1);

    final (overline, title, reason) = switch (result.reason) {
      GameEndReason.checkmate when tone == ResultTone.win => (
        'Checkmate',
        'You won',
        'You mated with $lastMove.',
      ),
      GameEndReason.checkmate => ('Checkmate', 'Stockfish won', 'Mate after $lastMove.'),
      GameEndReason.stalemate => (
        'Stalemate',
        'Draw',
        game.turn == player
            ? 'You have no legal move and aren’t in check.'
            : 'Stockfish has no legal move and isn’t in check.',
      ),
      GameEndReason.threefoldRepetition => (
        'Threefold repetition',
        'Draw',
        'The same position appeared three times.',
      ),
      GameEndReason.fiftyMoveRule => (
        '50-move rule',
        'Draw',
        '50 moves each with no capture or pawn move.',
      ),
      GameEndReason.insufficientMaterial => (
        'Insufficient material',
        'Draw',
        'Neither side has enough pieces left to mate.',
      ),
      GameEndReason.resignation => (
        'Resignation',
        'You resigned',
        'Game ended on move $moveNumber.',
      ),
      // The flagged side is always the side to move.
      GameEndReason.timeout when tone == ResultTone.draw => (
        'Timeout',
        'Draw',
        game.turn == player
            ? 'Your clock ran out, but Stockfish can’t mate.'
            : 'Stockfish’s clock ran out, but you can’t mate.',
      ),
      GameEndReason.timeout when tone == ResultTone.win => (
        'Timeout',
        'You won on time',
        'Stockfish’s clock ran out on move $moveNumber.',
      ),
      GameEndReason.timeout => (
        'Timeout',
        'Stockfish won on time',
        'Your clock ran out on move $moveNumber.',
      ),
      GameEndReason.agreement => ('Draw agreed', 'Draw', 'Stockfish accepted your draw offer.'),
    };

    final score = switch (result.winner) {
      Side.white => '1–0',
      Side.black => '0–1',
      null => '½–½',
    };
    return ResultCopy(overline: overline, title: title, reason: reason, score: score, tone: tone);
  }

  final String overline;
  final String title;
  final String reason;
  final String score;
  final ResultTone tone;
}

/// A move with its number, as in a score sheet: `39. b8=Q#` or `31…Re1#`.
String moveLabel(GameState game, int index) {
  final number = moveNumber(game, index);
  final move = game.moves[index];
  return move.side == Side.white ? '$number. ${move.san}' : '$number…${move.san}';
}

/// The full-move number of move [index], counted from the game's start.
int moveNumber(GameState game, int index) {
  final start = game.history.first;
  // Plies before this move, counted from the start position.
  final ply = index + (start.turn == Side.black ? 1 : 0);
  return start.fullmoves + ply ~/ 2;
}
