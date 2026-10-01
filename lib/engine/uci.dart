import 'package:flutter/foundation.dart';

/// An engine evaluation from the side to move's point of view.
@immutable
class EngineScore {
  const EngineScore.centipawns(int this.centipawns) : mate = null;

  const EngineScore.mate(int this.mate) : centipawns = null;

  /// Positive is good for the side to move.
  final int? centipawns;

  /// Moves to mate: positive when the side to move mates, negative when it
  /// gets mated.
  final int? mate;

  /// Score in pawns, with mates counted as ±100 so they sort above anything.
  double get pawns => mate != null ? (mate! > 0 ? 100 : -100) : centipawns! / 100;

  @override
  bool operator ==(Object other) =>
      other is EngineScore && other.centipawns == centipawns && other.mate == mate;

  @override
  int get hashCode => Object.hash(centipawns, mate);

  @override
  String toString() => mate != null ? '#$mate' : '${centipawns}cp';
}

/// Win, draw and loss chances in permille (they add up to 1000).
typedef Wdl = ({int win, int draw, int loss});

/// One principal variation from a `info ... multipv N ... pv ...` line.
@immutable
class EngineLine {
  const EngineLine({
    required this.rank,
    required this.depth,
    required this.score,
    required this.pv,
    this.wdl,
  });

  /// 1 for the engine's top choice, 2 for the next, and so on.
  final int rank;
  final int depth;
  final EngineScore score;

  /// Moves in UCI notation (`e2e4`, `e7e8q`), first move first.
  final List<String> pv;

  /// Stockfish's win/draw/loss chances in permille, from the side to move's
  /// point of view (`UCI_ShowWDL`); null when the engine didn't send them.
  final Wdl? wdl;

  String get move => pv.first;

  @override
  String toString() => 'EngineLine(#$rank d$depth $score ${pv.join(' ')})';
}

/// Parses the few UCI output lines Rooksight needs.
abstract final class UciParser {
  /// Parses an `info` line that carries a score and a principal variation.
  /// Returns null for any other line (e.g. `info string ...`, `info currmove`).
  static EngineLine? parseInfo(String line) {
    final tokens = line.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.first != 'info') return null;

    int? depth;
    int rank = 1;
    EngineScore? score;
    Wdl? wdl;
    List<String>? pv;

    for (var i = 1; i < tokens.length; i++) {
      switch (tokens[i]) {
        case 'depth' when i + 1 < tokens.length:
          depth = int.tryParse(tokens[++i]);
        case 'multipv' when i + 1 < tokens.length:
          rank = int.tryParse(tokens[++i]) ?? 1;
        case 'score' when i + 2 < tokens.length:
          final value = int.tryParse(tokens[i + 2]);
          if (value != null) {
            score = switch (tokens[i + 1]) {
              'cp' => EngineScore.centipawns(value),
              'mate' => EngineScore.mate(value),
              _ => null,
            };
          }
          i += 2;
        case 'wdl' when i + 3 < tokens.length:
          final (w, d, l) = (
            int.tryParse(tokens[i + 1]),
            int.tryParse(tokens[i + 2]),
            int.tryParse(tokens[i + 3]),
          );
          if (w != null && d != null && l != null) wdl = (win: w, draw: d, loss: l);
          i += 3;
        case 'pv':
          // `pv` is always last: everything after it is the variation.
          pv = tokens.sublist(i + 1);
          i = tokens.length;
      }
    }

    if (depth == null || score == null || pv == null || pv.isEmpty) return null;
    return EngineLine(rank: rank, depth: depth, score: score, pv: pv, wdl: wdl);
  }

  /// The move from a `bestmove e2e4 ponder e7e5` line, or null for other
  /// lines and for `bestmove (none)` (no legal moves).
  static String? parseBestMove(String line) {
    final tokens = line.trim().split(RegExp(r'\s+'));
    if (tokens.length < 2 || tokens.first != 'bestmove') return null;
    return tokens[1] == '(none)' ? null : tokens[1];
  }
}
