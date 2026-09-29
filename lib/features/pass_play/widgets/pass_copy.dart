import 'package:dartchess/dartchess.dart';

import '../../play/domain/game_result.dart';
import '../../play/widgets/result_copy.dart';
import '../domain/pass_config.dart';
import '../domain/pass_session.dart';

/// [verb] agreeing with [name]: "You offer", "Opponent offers".
String verbFor(String name, String verb) => name == PassConfig.defaultFirstName ? verb : '${verb}s';

/// "Your" or "Opponent’s".
String possessive(String name) => name == PassConfig.defaultFirstName ? 'Your' : '$name’s';

/// The offer's question, e.g. "You ask to take back 23. Nxd5".
String requestTitle(PassSession session, PassRequest request) {
  final name = session.config.nameOf(request.from);
  final game = session.game;
  return switch (request.kind) {
    PassRequestKind.draw => '$name ${verbFor(name, 'offer')} a draw',
    PassRequestKind.takeback =>
      '$name ${verbFor(name, 'ask')} to take back ${moveLabel(game, game.moves.length - 1)}',
  };
}

/// The result sheet's text for a finished pass & play game, with both
/// players' names. A decisive result takes the win colour: someone on this
/// phone won.
ResultCopy passResultCopy(PassSession session) {
  final game = session.game;
  final result = game.result!;
  final config = session.config;
  final winner = result.winner;
  final winnerName = winner == null ? '' : config.nameOf(winner);
  final wins = '$winnerName ${verbFor(winnerName, 'win')}';
  // The flagged side, or the side to move for stalemate, is the one to move.
  final toMove = config.nameOf(game.turn);
  final moveNumber = game.position.fullmoves;
  final lastMove = game.moves.isEmpty ? '' : moveLabel(game, game.moves.length - 1);

  final (overline, title, reason) = switch (result.reason) {
    GameEndReason.checkmate => ('Checkmate', wins, 'Mate with $lastMove.'),
    GameEndReason.stalemate => (
      'Stalemate',
      'Draw',
      '$toMove ${toMove == PassConfig.defaultFirstName ? 'have' : 'has'} no legal move '
          'and ${toMove == PassConfig.defaultFirstName ? 'aren’t' : 'isn’t'} in check.',
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
      wins,
      '${config.nameOf(winner!.opposite)} resigned on move $moveNumber.',
    ),
    GameEndReason.timeout when winner == null => (
      'Timeout',
      'Draw',
      '${possessive(toMove)} clock ran out, but '
          '${config.nameOf(game.turn.opposite)} can’t mate.',
    ),
    GameEndReason.timeout => (
      'Timeout',
      '$wins on time',
      '${possessive(toMove)} clock ran out on move $moveNumber.',
    ),
    GameEndReason.agreement => ('Draw agreed', 'Draw', 'Both players agreed to a draw.'),
  };

  return ResultCopy(
    overline: overline,
    title: title,
    reason: reason,
    score: switch (winner) {
      Side.white => '1–0',
      Side.black => '0–1',
      null => '½–½',
    },
    tone: winner == null ? ResultTone.draw : ResultTone.win,
  );
}
