import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'game_result.dart';
import 'game_rules.dart';

/// A move as played in the game, with what the UI needs to show it.
@immutable
class PlayedMove {
  const PlayedMove({
    required this.move,
    required this.san,
    required this.side,
    this.captured,
    this.isEnPassant = false,
  });

  /// Normalised by `dartchess` (castling is stored as king-takes-rook).
  final Move move;

  /// Standard Algebraic Notation, with `+` / `#` suffix.
  final String san;

  /// Who played it.
  final Side side;

  /// The piece this move captured, if any (a pawn for en passant).
  final Role? captured;

  /// The move list marks these "e.p.".
  final bool isEnPassant;
}

/// Immutable state of one game. All rules come from `dartchess` plus
/// [GameRules]; this class never judges legality itself.
@immutable
class GameState {
  GameState._({required List<Position> history, required List<PlayedMove> moves, this.result})
    : history = List.unmodifiable(history),
      moves = List.unmodifiable(moves);

  /// A new game from [start] (the standard starting position by default).
  factory GameState.start([Position start = Chess.initial]) =>
      GameState._(history: [start], moves: const []);

  /// Every position of the game, starting position first. Always one longer
  /// than [moves].
  final List<Position> history;

  final List<PlayedMove> moves;

  /// Null while the game is in progress.
  final GameResult? result;

  Position get position => history.last;

  Side get turn => position.turn;

  bool get isOver => result != null;

  /// The last move as played, for the board's last-move highlight.
  Move? get lastMove => moves.isEmpty ? null : moves.last.move;

  /// The square of the king in check, if any.
  Square? get checkedKing => position.isCheck ? position.board.kingOf(position.turn) : null;

  /// Pieces [side] has captured, most valuable first.
  List<Role> capturedBy(Side side) {
    final roles = [
      for (final m in moves)
        if (m.side == side && m.captured != null) m.captured!,
    ];
    return roles..sort((a, b) => pieceValue(b).compareTo(pieceValue(a)));
  }

  /// How many points of material [side] is ahead (negative when behind).
  /// Counts the board, so promotions are included.
  int materialAdvantage(Side side) => _material(side) - _material(side.opposite);

  int _material(Side side) {
    final board = position.board;
    var total = 0;
    for (final role in Role.values) {
      total += board.piecesOf(side, role).size * pieceValue(role);
    }
    return total;
  }

  /// Plays [move] and returns the new state, or null if the move is illegal
  /// or the game is over.
  GameState? play(Move move) {
    if (isOver || !position.isLegal(move) || _missingPromotion(move)) return null;
    final normalized = move is NormalMove ? position.normalizeMove(move) : move;
    final (captured, isEnPassant) = _capture(normalized);
    final (next, san) = position.makeSanUnchecked(normalized);
    final history = [...this.history, next];
    return GameState._(
      history: history,
      moves: [
        ...moves,
        PlayedMove(
          move: normalized,
          san: san,
          side: position.turn,
          captured: captured,
          isEnPassant: isEnPassant,
        ),
      ],
      result: GameRules.resultOf(history),
    );
  }

  /// Ends the game with [result] (resignation, timeout, agreed draw).
  GameState finish(GameResult result) =>
      GameState._(history: history, moves: moves, result: result);

  /// Takes back the last [plies] moves. Clears any result.
  GameState undo([int plies = 1]) {
    final keep = (moves.length - plies).clamp(0, moves.length);
    return GameState._(history: history.sublist(0, keep + 1), moves: moves.sublist(0, keep));
  }

  /// `dartchess` accepts a pawn reaching the last rank without a promotion
  /// piece; the board always supplies one, but reject it here too.
  bool _missingPromotion(Move move) {
    if (move is! NormalMove || move.promotion != null) return false;
    final isPawn = position.board.pieceAt(move.from)?.role == Role.pawn;
    return isPawn && (move.to.rank == Rank.first || move.to.rank == Rank.eighth);
  }

  /// The piece [move] captures, and whether it is en passant.
  (Role?, bool) _capture(Move move) {
    if (move is! NormalMove) return (null, false);
    final target = position.board.pieceAt(move.to);
    // Castling is stored as king-takes-own-rook: not a capture.
    if (target != null) return (target.color != position.turn ? target.role : null, false);
    final mover = position.board.pieceAt(move.from);
    final isEnPassant = mover?.role == Role.pawn && move.from.file != move.to.file;
    return (isEnPassant ? Role.pawn : null, isEnPassant);
  }
}

/// Standard piece values in pawns. The king counts as 0.
int pieceValue(Role role) => switch (role) {
  Role.pawn => 1,
  Role.knight => 3,
  Role.bishop => 3,
  Role.rook => 5,
  Role.queen => 9,
  Role.king => 0,
};
