// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'game_config.dart';

/// Chess clocks. Immutable: every change takes the current time, so the logic
/// is testable without real time passing.
///
/// In pass & play both sides are timed, and one clock runs at a time. Against
/// Stockfish only the [owner] (the player) is timed: their clock runs on their
/// turn and stops when they move, while Stockfish thinks as long as it needs,
/// is never charged and can't lose on time. Remaining time is stored as of the
/// moment the running clock last started ([runningSince]).
@immutable
class GameClock {
  const GameClock._({
    required this.white,
    required this.black,
    required this.increment,
    required this.owner,
    this.running,
    this.runningSince,
  });

  /// Full clocks, not running. They first start once White has moved (and,
  /// with an [owner], only on the owner's turn).
  factory GameClock.start(TimeControl control, {Side? owner}) => GameClock._(
    white: control.initial,
    black: control.initial,
    increment: control.increment,
    owner: owner,
  );

  /// Stopped clocks with [white] and [black] left (a resumed game).
  factory GameClock.stopped({
    required Duration white,
    required Duration black,
    required Duration increment,
    Side? owner,
  }) => GameClock._(white: white, black: black, increment: increment, owner: owner);

  final Duration white;
  final Duration black;
  final Duration increment;

  /// The only timed side (the player, against Stockfish), or null when both
  /// sides are timed. An untimed side's time never changes.
  final Side? owner;

  /// The side whose clock is running, or null when stopped.
  final Side? running;
  final DateTime? runningSince;

  bool get isRunning => running != null;

  /// Whether [side]'s time counts.
  bool isTimed(Side side) => owner == null || owner == side;

  /// Time left for [side] at [now], never below zero.
  Duration remaining(Side side, DateTime now) {
    final stored = side == Side.white ? white : black;
    if (side != running) return stored;
    final left = stored - now.difference(runningSince!);
    return left.isNegative ? Duration.zero : left;
  }

  /// [mover] has just moved: if they're timed, charge the time used and add
  /// the increment; then start the other side's clock if they're timed. A
  /// move made while the mover's clock wasn't running (White's first move)
  /// costs nothing and earns no increment.
  GameClock afterMove(Side mover, DateTime now) {
    final charged = isTimed(mover)
        ? _with(mover, running == mover ? remaining(mover, now) + increment : _stored(mover))
        : stop(now);
    final next = mover.opposite;
    return isTimed(next) ? charged._run(next, now) : charged._run(null, null);
  }

  /// Stops both clocks, keeping the time left.
  GameClock stop(DateTime now) {
    final side = running;
    if (side == null) return this;
    return _with(side, remaining(side, now))._run(null, null);
  }

  /// Restarts [side]'s clock from its stored time (after a take-back, a
  /// pause, or when the app comes back to the foreground). It stays stopped
  /// when [side] isn't timed.
  GameClock resume(Side side, DateTime now) {
    final stopped = stop(now);
    return isTimed(side) ? stopped._run(side, now) : stopped;
  }

  Duration _stored(Side side) => side == Side.white ? white : black;

  GameClock _with(Side side, Duration time) => GameClock._(
    white: side == Side.white ? time : white,
    black: side == Side.black ? time : black,
    increment: increment,
    owner: owner,
    running: running,
    runningSince: runningSince,
  );

  GameClock _run(Side? side, DateTime? since) => GameClock._(
    white: white,
    black: black,
    increment: increment,
    owner: owner,
    running: side,
    runningSince: since,
  );
}
