import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../play/domain/game_clock.dart';
import '../../play/domain/game_state.dart';
import 'pass_config.dart';

/// What one player asks the other on the same phone.
enum PassRequestKind { takeback, draw }

/// A takeback or draw offer from [from], waiting for the other player.
@immutable
class PassRequest {
  const PassRequest(this.kind, this.from);

  final PassRequestKind kind;
  final Side from;

  /// Who has to answer.
  Side get answerer => from.opposite;

  @override
  bool operator ==(Object other) =>
      other is PassRequest && other.kind == kind && other.from == from;

  @override
  int get hashCode => Object.hash(kind, from);
}

/// Everything the pass & play screen shows: the game, both clocks, and what
/// the players are doing around it (pause, offers).
@immutable
class PassSession {
  const PassSession({
    required this.config,
    required this.game,
    this.clock,
    this.clockTimes = const [],
    this.paused = false,
    this.request,
    this.lastDrawOffer,
    this.notice,
    this.startedAt,
    this.savedGameId,
    this.saveFailed = false,
  });

  final PassConfig config;
  final GameState game;

  /// Both players' clocks; null without a clock.
  final GameClock? clock;

  /// Time left for the mover after each move (increment included), for the
  /// PGN's `%clk` comments. Empty without a clock.
  final List<Duration> clockTimes;

  /// Both clocks stopped and the board hidden.
  final bool paused;

  /// A takeback or draw offer waiting for an answer.
  final PassRequest? request;

  /// Who last offered a draw, and at which ply: one offer per side per move.
  final ({Side side, int ply})? lastDrawOffer;

  /// A short message, e.g. a declined offer.
  final String? notice;

  final DateTime? startedAt;

  /// Set once the finished game is stored.
  final int? savedGameId;

  /// Storing the finished game failed.
  final bool saveFailed;

  /// Moves can be played: not over, not paused, no offer waiting.
  bool get canMove => !game.isOver && !paused && request == null;

  /// Who made the last move: the only player who may ask to take it back.
  Side? get takebackSide => canMove && config.takebacks ? game.moves.lastOrNull?.side : null;

  /// Whether [side] may offer a draw now.
  bool canOfferDraw(Side side) => canMove && lastDrawOffer != (side: side, ply: game.moves.length);

  PassSession copyWith({
    PassConfig? config,
    GameState? game,
    GameClock? Function()? clock,
    List<Duration>? clockTimes,
    bool? paused,
    PassRequest? Function()? request,
    ({Side side, int ply})? Function()? lastDrawOffer,
    String? Function()? notice,
    int? savedGameId,
    bool? saveFailed,
  }) {
    return PassSession(
      config: config ?? this.config,
      game: game ?? this.game,
      clock: clock != null ? clock() : this.clock,
      clockTimes: clockTimes ?? this.clockTimes,
      paused: paused ?? this.paused,
      request: request != null ? request() : this.request,
      lastDrawOffer: lastDrawOffer != null ? lastDrawOffer() : this.lastDrawOffer,
      notice: notice != null ? notice() : this.notice,
      startedAt: startedAt,
      savedGameId: savedGameId ?? this.savedGameId,
      saveFailed: saveFailed ?? this.saveFailed,
    );
  }
}
