import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/game_repository.dart';

/// One month of a player's games, e.g. `…/games/2026/03`.
@immutable
class ArchiveMonth implements Comparable<ArchiveMonth> {
  const ArchiveMonth(this.year, this.month, this.url);

  /// Parses an archive URL from `/games/archives`, or null if it isn't one.
  static ArchiveMonth? fromUrl(String url) {
    final match = RegExp(r'/games/(\d{4})/(\d{2})$').firstMatch(url);
    if (match == null) return null;
    return ArchiveMonth(int.parse(match[1]!), int.parse(match[2]!), Uri.parse(url));
  }

  final int year;
  final int month;
  final Uri url;

  /// `2026/03`, as in the URL; the key in the import log.
  String get key => '$year/${month.toString().padLeft(2, '0')}';

  /// Months since year 0, for comparing and counting back.
  int get index => year * 12 + month - 1;

  @override
  int compareTo(ArchiveMonth other) => index.compareTo(other.index);

  @override
  bool operator ==(Object other) => other is ArchiveMonth && other.index == index;

  @override
  int get hashCode => index;

  @override
  String toString() => key;
}

/// One side of a Chess.com game.
@immutable
class ChessComPlayer {
  const ChessComPlayer({required this.username, required this.rating, required this.result});

  factory ChessComPlayer.fromJson(Map<String, Object?> json) => ChessComPlayer(
    username: json['username'] as String? ?? '?',
    rating: (json['rating'] as num?)?.toInt(),
    result: json['result'] as String? ?? '',
  );

  final String username;
  final int? rating;

  /// Chess.com's result code for this side: `win`, `checkmated`, `agreed`, …
  final String result;
}

/// A game from a monthly archive.
@immutable
class ChessComGame {
  const ChessComGame({
    required this.url,
    required this.pgn,
    required this.rules,
    required this.timeClass,
    required this.timeControl,
    required this.endTime,
    required this.white,
    required this.black,
  });

  factory ChessComGame.fromJson(Map<String, Object?> json) => ChessComGame(
    url: json['url'] as String? ?? '',
    pgn: json['pgn'] as String? ?? '',
    rules: json['rules'] as String? ?? 'chess',
    timeClass: json['time_class'] as String?,
    timeControl: json['time_control'] as String?,
    endTime: DateTime.fromMillisecondsSinceEpoch(
      ((json['end_time'] as num?) ?? 0).toInt() * 1000,
      isUtc: true,
    ),
    white: ChessComPlayer.fromJson(json['white'] as Map<String, Object?>? ?? const {}),
    black: ChessComPlayer.fromJson(json['black'] as Map<String, Object?>? ?? const {}),
  );

  final String url;
  final String pgn;

  /// `chess` for standard chess; variants (`chess960`, …) are not imported.
  final String rules;

  /// `bullet`, `blitz`, `rapid` or `daily`.
  final String? timeClass;

  /// `180+2`, `600`, or `1/86400` for daily games.
  final String? timeControl;
  final DateTime endTime;
  final ChessComPlayer white;
  final ChessComPlayer black;

  bool get isStandardChess => rules == 'chess';

  /// The game as a [GameRecord] from [username]'s side, or null if it can't
  /// be imported (a variant, a game [username] didn't play, or no moves).
  GameRecord? toRecord(String username) {
    if (!isStandardChess || pgn.isEmpty) return null;
    final user = username.toLowerCase();
    final Side side;
    if (white.username.toLowerCase() == user) {
      side = Side.white;
    } else if (black.username.toLowerCase() == user) {
      side = Side.black;
    } else {
      return null;
    }

    final plies = PgnGame.parsePgn(pgn).moves.mainline().length;
    if (plies == 0) return null;

    final (player, opponent) = side == Side.white ? (white, black) : (black, white);
    return GameRecord(
      source: GameSource.chesscom,
      externalId: url,
      pgn: pgn,
      playerSide: side,
      result: _pgnResult(),
      endReason: _endReason(),
      opponentName: opponent.username,
      opponentRating: opponent.rating,
      playerRating: player.rating,
      timeClass: timeClass,
      // Bare seconds ("600") become "600+0", matching our own games.
      timeControl: timeControl == null
          ? null
          : RegExp(r'^\d+$').hasMatch(timeControl!)
          ? '$timeControl+0'
          : timeControl,
      plyCount: plies,
      startedAt: endTime,
      endedAt: endTime,
    );
  }

  String _pgnResult() => white.result == 'win'
      ? '1-0'
      : black.result == 'win'
      ? '0-1'
      : '1/2-1/2';

  /// Chess.com result codes as Rooksight end reasons. The loser's code says
  /// why a decisive game ended; both sides share the code for a draw.
  String? _endReason() {
    final code = white.result == 'win' ? black.result : white.result;
    return switch (code) {
      'checkmated' => 'checkmate',
      'resigned' => 'resignation',
      'timeout' || 'timevsinsufficient' => 'timeout',
      'abandoned' => 'abandoned',
      'agreed' => 'agreement',
      'repetition' => 'threefoldRepetition',
      'stalemate' => 'stalemate',
      'insufficient' => 'insufficientMaterial',
      '50move' => 'fiftyMoveRule',
      _ => null,
    };
  }
}
