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

  /// Kept with a saved chat, so the card still shows (and the move check
  /// still knows it) when the chat is reopened, even if the game is gone.
  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'index': index,
    'label': label,
    'quality': ?quality?.name,
    'best': ?best,
    'fen': fen,
    'lastMove': lastMove.uci,
    'orientation': orientation.name,
    'opponent': opponent,
    'playedAt': playedAt.toIso8601String(),
  };

  /// Null if [json] can't be read.
  static CoachMove? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      return CoachMove(
        gameId: json['gameId']! as int,
        index: json['index']! as int,
        label: json['label']! as String,
        quality: MoveQuality.values.where((q) => q.name == json['quality']).firstOrNull,
        best: json['best'] as String?,
        fen: json['fen']! as String,
        lastMove: Move.parse(json['lastMove']! as String)!,
        orientation: Side.values.byName(json['orientation']! as String),
        opponent: json['opponent']! as String,
        playedAt: DateTime.parse(json['playedAt']! as String),
      );
    } on Object {
      return null;
    }
  }
}
