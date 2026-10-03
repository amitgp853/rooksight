// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'game_clock.dart';
import 'game_config.dart';
import 'game_state.dart';

/// A suggested move for the player, shown as a brass arrow plus a line of text.
@immutable
class Hint {
  const Hint({required this.move, required this.text});

  final NormalMove move;
  final String text;
}

/// Everything the game screen shows: the chess game plus what happens around
/// it (engine thinking, hint, errors).
@immutable
class GameSession {
  const GameSession({
    required this.config,
    required this.game,
    this.engineThinking = false,
    this.hint,
    this.hintsUsed = 0,
    this.engineError = false,
    this.clock,
    this.notice,
    this.drawOfferedAtPly,
    this.startedAt,
    this.savedGameId,
    this.saveFailed = false,
    this.paused = false,
    this.premove,
  });

  final GameConfig config;
  final GameState game;

  /// Stockfish is taking a while (shown only after 300ms, so quick replies
  /// don't flicker).
  final bool engineThinking;

  final Hint? hint;
  final int hintsUsed;

  /// Stockfish failed to answer; the screen offers a retry.
  final bool engineError;

  /// Null when playing without a clock.
  final GameClock? clock;

  /// A short message for the player, e.g. a declined draw offer.
  final String? notice;

  /// The ply at which the player last offered a draw (one offer per move).
  final int? drawOfferedAtPly;

  final DateTime? startedAt;

  /// Set once the finished game is stored.
  final int? savedGameId;

  /// Storing the finished game failed.
  final bool saveFailed;

  /// The player paused a timed game: the clock is stopped, the board hidden.
  final bool paused;

  /// A move the player queued during Stockfish's turn, played as soon as
  /// Stockfish replies if it is still legal then.
  final Move? premove;

  /// A timed game still going can be paused.
  bool get canPause => clock != null && !game.isOver;

  bool get isPlayerTurn => !game.isOver && !paused && game.turn == config.playerSide;

  /// Whether the player may offer a draw now.
  bool get canOfferDraw => !game.isOver && drawOfferedAtPly != game.moves.length;

  /// Take-backs are allowed in practice mode once the player has moved.
  bool get canUndo => config.practice && game.moves.any((move) => move.side == config.playerSide);

  GameSession copyWith({
    GameConfig? config,
    GameState? game,
    bool? engineThinking,
    Hint? Function()? hint,
    int? hintsUsed,
    bool? engineError,
    GameClock? Function()? clock,
    String? Function()? notice,
    int? Function()? drawOfferedAtPly,
    int? savedGameId,
    bool? saveFailed,
    bool? paused,
    Move? Function()? premove,
  }) {
    return GameSession(
      config: config ?? this.config,
      game: game ?? this.game,
      engineThinking: engineThinking ?? this.engineThinking,
      hint: hint != null ? hint() : this.hint,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      engineError: engineError ?? this.engineError,
      clock: clock != null ? clock() : this.clock,
      notice: notice != null ? notice() : this.notice,
      drawOfferedAtPly: drawOfferedAtPly != null ? drawOfferedAtPly() : this.drawOfferedAtPly,
      startedAt: startedAt,
      savedGameId: savedGameId ?? this.savedGameId,
      saveFailed: saveFailed ?? this.saveFailed,
      paused: paused ?? this.paused,
      premove: premove != null ? premove() : this.premove,
    );
  }
}
