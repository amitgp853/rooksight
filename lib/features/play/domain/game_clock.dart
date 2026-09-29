import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'game_config.dart';

/// Chess clocks for both sides. Immutable: every change takes the current
/// time, so the logic is testable without real time passing.
///
/// Only one side's clock runs at a time. Remaining time is stored as of the
/// moment the running clock last started ([runningSince]).
@immutable
class GameClock {
  const GameClock._({
    required this.white,
    required this.black,
    required this.increment,
    this.running,
    this.runningSince,
  });

  /// Both clocks full, neither running. They start after White's first move.
  factory GameClock.start(TimeControl control) =>
      GameClock._(white: control.initial, black: control.initial, increment: control.increment);

  /// Stopped clocks with [white] and [black] left (a resumed game).
  factory GameClock.stopped({
    required Duration white,
    required Duration black,
    required Duration increment,
  }) => GameClock._(white: white, black: black, increment: increment);

  final Duration white;
  final Duration black;
  final Duration increment;

  /// The side whose clock is running, or null when stopped.
  final Side? running;
  final DateTime? runningSince;

  bool get isRunning => running != null;

  /// Time left for [side] at [now], never below zero.
  Duration remaining(Side side, DateTime now) {
    final stored = side == Side.white ? white : black;
    if (side != running) return stored;
    final left = stored - now.difference(runningSince!);
    return left.isNegative ? Duration.zero : left;
  }

  /// [mover] has just moved: charge them the time used, add the increment,
  /// and start the opponent's clock. A move made while [mover]'s clock wasn't
  /// running (White's first move) costs nothing and earns no increment.
  GameClock afterMove(Side mover, DateTime now) {
    final left = running == mover ? remaining(mover, now) + increment : _stored(mover);
    return _with(mover, left)._run(mover.opposite, now);
  }

  /// Stops both clocks, keeping the time left.
  GameClock stop(DateTime now) {
    final side = running;
    if (side == null) return this;
    return _with(side, remaining(side, now))._run(null, null);
  }

  /// Starts [side]'s clock from its stored time (after a take-back or when
  /// the app comes back to the foreground).
  GameClock resume(Side side, DateTime now) => stop(now)._run(side, now);

  Duration _stored(Side side) => side == Side.white ? white : black;

  GameClock _with(Side side, Duration time) => GameClock._(
    white: side == Side.white ? time : white,
    black: side == Side.black ? time : black,
    increment: increment,
    running: running,
    runningSince: runningSince,
  );

  GameClock _run(Side? side, DateTime? since) => GameClock._(
    white: white,
    black: black,
    increment: increment,
    running: side,
    runningSince: since,
  );
}
