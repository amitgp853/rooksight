// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/game_repository.dart';

/// One side of a Lichess game: a player, or Stockfish ("AI level N").
@immutable
class LichessPlayer {
  const LichessPlayer({this.name, this.rating, this.aiLevel});

  factory LichessPlayer.fromJson(Map<String, Object?> json) {
    final user = json['user'] as Map<String, Object?>?;
    return LichessPlayer(
      name: user?['name'] as String? ?? user?['id'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      aiLevel: (json['aiLevel'] as num?)?.toInt(),
    );
  }

  /// Null for Lichess's computer opponent (and anonymous players).
  final String? name;
  final int? rating;
  final int? aiLevel;

  String get displayName => name ?? (aiLevel != null ? 'Lichess AI level $aiLevel' : 'Anonymous');
}

/// A game from Lichess's export API (NDJSON, one game per line, with the PGN
/// and opening included).
@immutable
class LichessGame {
  const LichessGame({
    required this.id,
    required this.variant,
    required this.speed,
    required this.status,
    required this.createdAt,
    required this.lastMoveAt,
    required this.white,
    required this.black,
    required this.pgn,
    this.winner,
    this.clockInitial,
    this.clockIncrement,
  });

  factory LichessGame.fromJson(Map<String, Object?> json) {
    final players = json['players'] as Map<String, Object?>? ?? const {};
    final clock = json['clock'] as Map<String, Object?>?;
    DateTime time(Object? ms) =>
        DateTime.fromMillisecondsSinceEpoch((ms as num? ?? 0).toInt(), isUtc: true);
    return LichessGame(
      id: json['id'] as String? ?? '',
      variant: json['variant'] as String? ?? 'standard',
      speed: json['speed'] as String?,
      status: json['status'] as String? ?? '',
      createdAt: time(json['createdAt']),
      lastMoveAt: time(json['lastMoveAt'] ?? json['createdAt']),
      white: LichessPlayer.fromJson(players['white'] as Map<String, Object?>? ?? const {}),
      black: LichessPlayer.fromJson(players['black'] as Map<String, Object?>? ?? const {}),
      pgn: json['pgn'] as String? ?? '',
      winner: json['winner'] as String?,
      clockInitial: (clock?['initial'] as num?)?.toInt(),
      clockIncrement: (clock?['increment'] as num?)?.toInt(),
    );
  }

  final String id;

  /// `standard` is imported; variants and `fromPosition` games are not.
  final String variant;

  /// `ultraBullet`, `bullet`, `blitz`, `rapid`, `classical`, `correspondence`.
  final String? speed;

  /// How it ended: `mate`, `resign`, `outoftime`, `draw`, `aborted`, …
  final String status;
  final DateTime createdAt;
  final DateTime lastMoveAt;
  final LichessPlayer white;
  final LichessPlayer black;
  final String pgn;

  /// `white` or `black`; null for a draw.
  final String? winner;

  /// Clock, in seconds; null for correspondence games.
  final int? clockInitial;
  final int? clockIncrement;

  String get url => 'https://lichess.org/$id';

  /// Statuses of games that never really happened or haven't ended.
  static const _unfinished = {'created', 'started', 'aborted', 'noStart', 'unknownFinish'};

  /// The game as a [GameRecord] from [username]'s side, or null if it can't
  /// be imported: a variant or custom start, unfinished, a game [username]
  /// didn't play, or no moves.
  GameRecord? toRecord(String username) {
    if (variant != 'standard' || _unfinished.contains(status) || pgn.isEmpty) return null;
    final user = username.trim().toLowerCase();
    final Side side;
    if (white.name?.toLowerCase() == user) {
      side = Side.white;
    } else if (black.name?.toLowerCase() == user) {
      side = Side.black;
    } else {
      return null;
    }

    final plies = PgnGame.parsePgn(pgn).moves.mainline().length;
    if (plies == 0) return null;

    final (player, opponent) = side == Side.white ? (white, black) : (black, white);
    return GameRecord(
      source: GameSource.lichess,
      externalId: url,
      pgn: pgn,
      playerSide: side,
      result: switch (winner) {
        'white' => '1-0',
        'black' => '0-1',
        _ => '1/2-1/2',
      },
      endReason: switch (status) {
        'mate' => 'checkmate',
        'resign' => 'resignation',
        'outoftime' => 'timeout',
        // The opponent left and the win was claimed.
        'timeout' => 'abandoned',
        'stalemate' => 'stalemate',
        'draw' => 'draw',
        _ => null,
      },
      opponentName: opponent.displayName,
      opponentRating: opponent.rating,
      playerRating: player.rating,
      // In Chess.com's terms, so stats and labels treat both alike.
      timeClass: switch (speed) {
        'ultraBullet' => 'bullet',
        'correspondence' => 'daily',
        final speed => speed,
      },
      timeControl: clockInitial == null ? null : '$clockInitial+${clockIncrement ?? 0}',
      plyCount: plies,
      startedAt: createdAt,
      endedAt: lastMoveAt,
    );
  }
}
