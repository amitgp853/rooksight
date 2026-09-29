import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/board/move_wise_board.dart';
import '../../../core/feedback/haptics.dart';
import '../domain/pass_controller.dart';
import '../domain/pass_session.dart';

/// The pass & play board: keeps chessground in sync with
/// [passControllerProvider]. Whoever's turn it is moves their pieces; nobody
/// can while the game is paused or an offer is waiting.
class PassBoard extends ConsumerStatefulWidget {
  const PassBoard({
    super.key,
    required this.orientation,
    this.size,
    this.onMove,
    this.facePlayerToMove = false,
  });

  final Side orientation;

  /// Defaults to the available width.
  final double? size;

  /// Called just before a move is played: whether it was dropped by drag (so
  /// it lands at once, without a slide).
  final void Function({required bool dragged})? onMove;

  /// Turns the pieces to face the player to move (face to face, where the
  /// board itself stays put between the players).
  final bool facePlayerToMove;

  @override
  ConsumerState<PassBoard> createState() => _PassBoardState();
}

class _PassBoardState extends ConsumerState<PassBoard> {
  late final ChessboardController _board = ChessboardController(
    game: _gameData(ref.read(passControllerProvider)),
  );

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  GameData _gameData(PassSession session) {
    final position = session.game.position;
    return GameData(
      fen: position.fen,
      lastMove: session.game.lastMove,
      // Either colour, but chessground only lets the side to move play.
      playerSide: session.canMove ? PlayerSide.both : PlayerSide.none,
      sideToMove: position.turn,
      validMoves: makeLegalMoves(position),
      kingSquareInCheck: session.game.checkedKing,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passControllerProvider, (previous, next) {
      if (previous?.game != next.game || previous?.canMove != next.canMove) {
        _board.updatePosition(_gameData(next));
      }
    });

    return MoveWiseBoard(
      controller: _board,
      orientation: widget.orientation,
      size: widget.size,
      pieceOrientation: widget.facePlayerToMove
          ? PieceOrientationBehavior.sideToPlay
          : PieceOrientationBehavior.facingUser,
      onTouchedSquare: (square) {
        final session = ref.read(passControllerProvider);
        final piece = session.game.position.board.pieceAt(square);
        if (session.canMove && piece?.color == session.game.turn) ref.haptic(Haptic.selection);
      },
      onMove: (move, {viaDragAndDrop}) {
        widget.onMove?.call(dragged: viaDragAndDrop ?? false);
        final played = ref.read(passControllerProvider.notifier).play(move);
        // The board only offers legal moves, but keep it honest if one fails.
        if (!played) _board.updatePosition(_gameData(ref.read(passControllerProvider)));
      },
    );
  }
}
