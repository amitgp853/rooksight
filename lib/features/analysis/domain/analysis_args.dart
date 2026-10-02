// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// Where the analysis board was opened from; sets its subtitle and Back.
enum AnalysisSource { scan, game, setup }

/// What the analysis board opens on: a start position, moves already
/// played from it (the main line), and how many of them to show.
@immutable
class AnalysisArgs {
  const AnalysisArgs({
    required this.fen,
    this.moves = const [],
    this.ply,
    this.source = AnalysisSource.setup,
    this.orientation = Side.white,
  });

  /// The start position.
  final String fen;

  /// The main line from [fen], in UCI (`e2e4`).
  final List<String> moves;

  /// Moves of [moves] played in the position shown first; all of them when
  /// null.
  final int? ply;
  final AnalysisSource source;

  /// The side at the bottom of the board.
  final Side orientation;

  static const path = '/analysis';

  /// The route to open these, as a location.
  String get location => Uri(
    path: path,
    queryParameters: {
      'fen': fen,
      if (moves.isNotEmpty) 'moves': moves.join(','),
      if (ply != null) 'ply': '$ply',
      'from': source.name,
      if (orientation == Side.black) 'side': 'black',
    },
  ).toString();

  /// From a location made by [location]. Unknown values fall back to the
  /// starting position and defaults.
  factory AnalysisArgs.fromQuery(Map<String, String> query) {
    final fen = query['fen'];
    return AnalysisArgs(
      fen: fen == null || fen.isEmpty ? Chess.initial.fen : fen,
      moves: [
        for (final m in (query['moves'] ?? '').split(','))
          if (m.isNotEmpty) m,
      ],
      ply: int.tryParse(query['ply'] ?? ''),
      source:
          AnalysisSource.values.where((s) => s.name == query['from']).firstOrNull ??
          AnalysisSource.setup,
      orientation: query['side'] == 'black' ? Side.black : Side.white,
    );
  }
}
