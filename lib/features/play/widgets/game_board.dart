import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/board/board_style.dart';
import '../../../core/board/move_wise_board.dart';
import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_controller.dart';
import '../domain/game_session.dart';

/// The board for the current game: keeps chessground's controller in sync
/// with [gameControllerProvider] and sends the player's moves back to it.
class GameBoard extends ConsumerStatefulWidget {
  const GameBoard({super.key, required this.orientation, this.size, this.onPlayerMove});

  final Side orientation;

  /// Defaults to the available width.
  final double? size;

  /// Called just before the player's move is played: whether it was dropped
  /// by drag (so it lands at once, without a slide).
  final void Function({required bool dragged})? onPlayerMove;

  @override
  ConsumerState<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends ConsumerState<GameBoard> {
  late final ChessboardController _board = ChessboardController(
    game: _gameData(ref.read(gameControllerProvider)),
  );

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  GameData _gameData(GameSession session) {
    final game = session.game;
    final position = game.position;
    return GameData(
      fen: position.fen,
      lastMove: game.lastMove,
      // The player can only move their own colour, and only on their turn
      // (chessground checks sideToMove).
      playerSide: game.isOver
          ? PlayerSide.none
          : session.config.playerSide == Side.white
          ? PlayerSide.white
          : PlayerSide.black,
      sideToMove: position.turn,
      validMoves: makeLegalMoves(position),
      kingSquareInCheck: game.checkedKing,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, (previous, next) {
      if (previous?.game != next.game) _board.updatePosition(_gameData(next));
    });
    final hint = ref.watch(gameControllerProvider.select((session) => session.hint));

    return MoveWiseBoard(
      controller: _board,
      orientation: widget.orientation,
      size: widget.size,
      shapes: {if (hint != null) hintArrow(context.colors, from: hint.move.from, to: hint.move.to)},
      onTouchedSquare: (square) {
        final session = ref.read(gameControllerProvider);
        final piece = session.game.position.board.pieceAt(square);
        if (session.isPlayerTurn && piece?.color == session.config.playerSide) {
          ref.haptic(Haptic.selection);
        }
      },
      onMove: (move, {viaDragAndDrop}) {
        widget.onPlayerMove?.call(dragged: viaDragAndDrop ?? false);
        final played = ref.read(gameControllerProvider.notifier).play(move);
        // The board only offers legal moves, but keep it honest if one fails.
        if (!played) _board.updatePosition(_gameData(ref.read(gameControllerProvider)));
      },
    );
  }
}
