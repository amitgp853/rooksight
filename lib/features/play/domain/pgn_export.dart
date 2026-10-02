// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';

import 'game_result.dart';
import 'game_session.dart';

/// The game in [session] as standard PGN, readable by Lichess, Chess.com
/// and any chess software.
String exportPgn(GameSession session, {required DateTime date}) {
  final game = session.game;
  final config = session.config;
  final start = game.history.first;
  final result = game.result;
  final engine = 'Stockfish ${config.level.elo}';
  final timeControl = config.timeControl;

  final headers = <String, String>{
    'Event': 'Rooksight vs Stockfish',
    'Site': 'Rooksight',
    'Date': _pgnDate(date),
    'Round': '-',
    'White': config.playerSide == Side.white ? 'You' : engine,
    'Black': config.playerSide == Side.black ? 'You' : engine,
    'Result': result?.pgn ?? '*',
    if (config.engineSide == Side.white) 'WhiteElo': '${config.level.elo}',
    if (config.engineSide == Side.black) 'BlackElo': '${config.level.elo}',
    'TimeControl': timeControl.hasClock
        ? '${timeControl.initial.inSeconds}+${timeControl.incrementSeconds}'
        : '-',
    'Termination': switch (result?.reason) {
      null => 'unterminated',
      GameEndReason.timeout => 'time forfeit',
      _ => 'normal',
    },
    if (start.fen != Chess.initial.fen) ...{'SetUp': '1', 'FEN': start.fen},
  };

  // A single main line: each move is the only child of the one before.
  final root = PgnNode<PgnNodeData>();
  PgnNode<PgnNodeData> node = root;
  for (final move in game.moves) {
    final child = PgnChildNode(PgnNodeData(san: move.san));
    node.children.add(child);
    node = child;
  }
  return PgnGame(headers: headers, moves: root, comments: const []).makePgn();
}

String _pgnDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
