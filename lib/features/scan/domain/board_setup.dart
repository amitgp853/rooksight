import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// A castling right: [side] may castle on [wing].
typedef CastlingRight = ({Side side, CastlingSide wing});

/// A position being set up by hand or checked after a scan: the pieces, plus
/// what a photo can't show (side to move, castling). Immutable; every edit
/// returns a new setup.
@immutable
class BoardSetup {
  BoardSetup({
    required Map<Square, Piece> pieces,
    this.turn = Side.white,
    Set<CastlingRight>? castling,
  }) : pieces = Map.unmodifiable(pieces),
       castling = Set.unmodifiable(castling ?? allCastlingRights);

  /// No pieces, White to move.
  factory BoardSetup.empty() => BoardSetup(pieces: const {});

  /// From the board part of a FEN (`rnbqkbnr/pppppppp/...`), or a whole FEN.
  factory BoardSetup.fromFen(String fen) {
    final setup = Setup.parseFen(fen.contains(' ') ? fen : '$fen w - - 0 1');
    return BoardSetup(
      pieces: {for (final (square, piece) in setup.board.pieces) square: piece},
      turn: setup.turn,
      castling: {
        for (final side in Side.values)
          for (final wing in CastlingSide.values)
            if (_hasRight(setup.castlingRights, side, wing)) (side: side, wing: wing),
      },
    );
  }

  /// From eight ranks as seen in a photo, top row first, each eight
  /// characters from left to right: `KQRBNP` white, `kqrbnp` black, `.` empty.
  /// With [whiteAtBottom] false (photo taken from Black's side) the grid is
  /// turned round. Returns null if the grid isn't 8 × 8 of those characters.
  static BoardSetup? fromRanks(List<String> ranks, {bool whiteAtBottom = true}) {
    if (ranks.length != 8) return null;
    final pieces = <Square, Piece>{};
    for (final (row, text) in ranks.indexed) {
      final cells = text.replaceAll(' ', '');
      if (cells.length != 8) return null;
      for (var col = 0; col < 8; col++) {
        final char = cells[col];
        if (char == '.') continue;
        final piece = Piece.fromChar(char);
        if (piece == null) return null;
        pieces[Square.fromCoords(File(col), Rank(7 - row))] = piece;
      }
    }
    final setup = BoardSetup(pieces: pieces);
    return whiteAtBottom ? setup : setup.rotated();
  }

  static const allCastlingRights = {
    (side: Side.white, wing: CastlingSide.king),
    (side: Side.white, wing: CastlingSide.queen),
    (side: Side.black, wing: CastlingSide.king),
    (side: Side.black, wing: CastlingSide.queen),
  };

  final Map<Square, Piece> pieces;
  final Side turn;

  /// The rights the player allows. Only those the pieces permit
  /// ([canCastle]) go into the FEN.
  final Set<CastlingRight> castling;

  Piece? pieceAt(Square square) => pieces[square];

  bool get isEmpty => pieces.isEmpty;

  BoardSetup copyWith({Map<Square, Piece>? pieces, Side? turn, Set<CastlingRight>? castling}) =>
      BoardSetup(
        pieces: pieces ?? this.pieces,
        turn: turn ?? this.turn,
        castling: castling ?? this.castling,
      );

  /// [piece] on [square], or the square emptied when null.
  BoardSetup withPiece(Square square, Piece? piece) {
    final next = {...pieces};
    if (piece == null) {
      next.remove(square);
    } else {
      next[square] = piece;
    }
    return copyWith(pieces: next);
  }

  /// Turned round (a1 ↔ h8): the photo was taken from the other side.
  BoardSetup rotated() => copyWith(
    pieces: {for (final MapEntry(:key, :value) in pieces.entries) Square(63 - key): value},
  );

  BoardSetup withCastling(CastlingRight right, {required bool allowed}) =>
      copyWith(castling: allowed ? {...castling, right} : ({...castling}..remove(right)));

  /// The king and that rook are on their starting squares.
  bool canCastle(CastlingRight right) {
    final rank = right.side == Side.white ? Rank.first : Rank.eighth;
    final king = pieces[Square.fromCoords(File.e, rank)];
    final rook = pieces[Square.fromCoords(right.wing == CastlingSide.king ? File.h : File.a, rank)];
    return king == Piece(color: right.side, role: Role.king) &&
        rook == Piece(color: right.side, role: Role.rook);
  }

  /// Castling rights that are both allowed and possible.
  Set<CastlingRight> get effectiveCastling => castling.where(canCastle).toSet();

  Board get board {
    var board = Board.empty;
    for (final MapEntry(:key, :value) in pieces.entries) {
      board = board.setPieceAt(key, value);
    }
    return board;
  }

  /// The whole FEN: no en passant, move 1.
  String get fen {
    final rights = effectiveCastling;
    final castles = [
      if (rights.contains((side: Side.white, wing: CastlingSide.king))) 'K',
      if (rights.contains((side: Side.white, wing: CastlingSide.queen))) 'Q',
      if (rights.contains((side: Side.black, wing: CastlingSide.king))) 'k',
      if (rights.contains((side: Side.black, wing: CastlingSide.queen))) 'q',
    ].join();
    return '${board.fen} ${turn == Side.white ? 'w' : 'b'} ${castles.isEmpty ? '-' : castles} - 0 1';
  }

  @override
  bool operator ==(Object other) =>
      other is BoardSetup &&
      other.turn == turn &&
      mapEquals(other.pieces, pieces) &&
      setEquals(other.castling, castling);

  @override
  int get hashCode => Object.hash(
    turn,
    Object.hashAllUnordered(pieces.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(castling),
  );

  static bool _hasRight(SquareSet rooks, Side side, CastlingSide wing) {
    final rank = side == Side.white ? Rank.first : Rank.eighth;
    final file = wing == CastlingSide.king ? File.h : File.a;
    return rooks.has(Square.fromCoords(file, rank));
  }
}
