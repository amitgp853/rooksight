// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';

import '../../play/domain/game_result.dart';
import 'pass_session.dart';

/// The pass & play game in [session] as standard PGN: both players' names,
/// the time control, and each player's clock after every move (`%clk`).
String exportPassPgn(PassSession session, {required DateTime date}) {
  final game = session.game;
  final config = session.config;
  final result = game.result;
  final timeControl = config.timeControl;

  final headers = <String, String>{
    'Event': 'Rooksight pass & play',
    'Site': 'Rooksight',
    'Date': '${date.year}.${_two(date.month)}.${_two(date.day)}',
    'Round': '-',
    'White': config.nameOf(Side.white),
    'Black': config.nameOf(Side.black),
    'Result': result?.pgn ?? '*',
    'TimeControl': timeControl.hasClock
        ? '${timeControl.initial.inSeconds}+${timeControl.incrementSeconds}'
        : '-',
    'Termination': switch (result?.reason) {
      null => 'unterminated',
      GameEndReason.timeout => 'time forfeit',
      _ => 'normal',
    },
  };

  // A single main line: each move is the only child of the one before.
  final root = PgnNode<PgnNodeData>();
  PgnNode<PgnNodeData> node = root;
  for (final (i, move) in game.moves.indexed) {
    final clock = i < session.clockTimes.length ? session.clockTimes[i] : null;
    final child = PgnChildNode(
      PgnNodeData(san: move.san, comments: clock == null ? null : ['[%clk ${pgnClock(clock)}]']),
    );
    node.children.add(child);
    node = child;
  }
  return PgnGame(headers: headers, moves: root, comments: const []).makePgn();
}

/// A clock reading as PGN writes it: `0:09:58`.
String pgnClock(Duration left) {
  final seconds = (left.inMilliseconds / 1000).ceil();
  return '${seconds ~/ 3600}:${_two(seconds ~/ 60 % 60)}:${_two(seconds % 60)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
