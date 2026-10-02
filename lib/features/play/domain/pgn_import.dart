// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';

import 'game_state.dart';

/// Replays the main line of [pgn] into a [GameState], stopping at the first
/// move that isn't legal (a damaged or truncated PGN still yields the moves
/// before it). The result stays null: callers read it from the PGN headers.
GameState gameFromPgn(String pgn) {
  final parsed = PgnGame.parsePgn(pgn);
  var state = GameState.start(PgnGame.startingPosition(parsed.headers));
  for (final node in parsed.moves.mainline()) {
    final move = state.position.parseSan(node.san);
    final next = move == null ? null : state.play(move);
    if (next == null) break;
    state = next;
  }
  return state;
}
