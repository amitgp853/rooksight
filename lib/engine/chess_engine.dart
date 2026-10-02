// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import 'uci.dart';

/// How hard and how strongly the engine should search.
@immutable
class SearchLimits {
  const SearchLimits({
    this.depth,
    this.moveTime,
    this.lines = 1,
    this.limitElo,
    this.skillLevel,
    this.stoppable = false,
  }) : assert(depth != null || moveTime != null, 'Give a depth or a move time');

  /// [ChessEngine.stop] may end this search early. Off by default, so one
  /// screen stopping its search never cuts short another's (a review
  /// running underneath the analysis board).
  final bool stoppable;

  /// Stop at this depth (plies).
  final int? depth;

  /// Stop after this long.
  final Duration? moveTime;

  /// Number of candidate lines to return (UCI `MultiPV`).
  final int lines;

  /// Play like this Elo (`UCI_LimitStrength` + `UCI_Elo`, 1320–3190).
  final int? limitElo;

  /// Stockfish `Skill Level`, 0–20. Ignored when [limitElo] is set.
  final int? skillLevel;
}

/// A chess engine behind an interface, so tests (and later the coach) can use
/// a fake. Searches run off the UI thread.
abstract interface class ChessEngine {
  /// Searches [fen] and returns the candidate lines, best first.
  ///
  /// Returns an empty list when the side to move has no legal moves.
  /// Searches are queued: a call waits for the previous one to finish.
  Future<List<EngineLine>> search(String fen, SearchLimits limits);

  /// Ends the running search early if it is [SearchLimits.stoppable]; it
  /// returns what it has found so far. Queued searches still run. Does
  /// nothing otherwise.
  void stop();

  /// Starts the engine ahead of the first search, to hide start-up time.
  Future<void> warmUp();

  Future<void> dispose();
}
