// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/engine/uci.dart';
import 'package:rooksight/features/play/domain/pgn_import.dart';
import 'package:rooksight/features/review/domain/game_analysis.dart';
import 'package:rooksight/features/review/domain/position_eval.dart';
import 'package:rooksight/features/stats/domain/player_stats.dart';
import 'package:rooksight/features/stats/domain/weaknesses.dart';

/// Scores from the side to move, one per position.
List<PositionEval> evals(List<(int?, int?, String)> scores) => [
  for (final (cp, mate, best) in scores)
    PositionEval(
      score: mate != null ? EngineScore.mate(mate) : EngineScore.centipawns(cp!),
      bestLine: [if (best.isNotEmpty) best],
      depth: 12,
    ),
];

var _id = 0;

/// A game as White (by default), reviewed when [scores] are given.
StatsGame game(
  String moves, {
  String result = '0-1',
  Side side = Side.white,
  String? endReason,
  List<(int?, int?, String)>? scores,
}) {
  final pgn = '[Result "$result"]\n\n$moves $result';
  final state = gameFromPgn(pgn);
  final record = GameRecord(
    source: GameSource.stockfish,
    pgn: pgn,
    playerSide: side,
    result: result,
    endReason: endReason,
    engineElo: 1200,
    plyCount: state.moves.length,
    startedAt: DateTime(2026, 9),
    endedAt: DateTime(2026, 9),
  );
  return StatsGame(
    SavedGame(++_id, record),
    state,
    scores == null ? null : GameAnalysis(state, evals(scores)),
  );
}

/// 3. Nd4?? leaves the knight to 3…Nxd4.
StatsGame hangsKnight() => game(
  '1. e4 e5 2. Nf3 Nc6 3. Nd4 Nxd4',
  scores: [
    (30, null, 'e2e4'),
    (-30, null, 'e7e5'),
    (30, null, 'g1f3'),
    (-30, null, 'b8c6'),
    (30, null, 'f1c4'),
    (300, null, 'c6d4'),
    (-300, null, 'c2c3'),
  ],
);

/// 2. g4?? allows Qh4#.
StatsGame allowsMate() => game(
  '1. f3 e5 2. g4 Qh4#',
  scores: [
    (20, null, 'e2e4'),
    (50, null, 'e7e5'),
    (-60, null, 'd2d4'),
    (null, 1, 'd8h4'),
    (null, 0, ''),
  ],
);

/// Black's 2…Qh4?? hangs the queen; 3. Nc3 misses it.
StatsGame missesQueen() => game(
  '1. e4 e5 2. Nf3 Qh4 3. Nc3',
  result: '1/2-1/2',
  scores: [
    (30, null, 'e2e4'),
    (-30, null, 'e7e5'),
    (30, null, 'g1f3'),
    (-30, null, 'b8c6'),
    (900, null, 'f3h4'),
    (50, null, 'h4e4'),
    (-50, null, 'd2d3'),
  ],
);

Weakness? kind(List<Weakness> found, WeaknessKind kind) =>
    found.where((w) => w.kind == kind).firstOrNull;

void main() {
  test('pieces left to be taken, in every game: first, and opens at the move', () {
    final games = [hangsKnight(), hangsKnight(), hangsKnight()];
    final found = findWeaknesses(games);
    final hanging = kind(found, WeaknessKind.hangingPieces)!;
    expect(hanging.games.values, everyElement(4));
    expect(hanging.share, 1);
    expect(hanging.detail, '3 blunders in 3 games lost a piece or more straight away.');
    expect(found.first.kind, WeaknessKind.hangingPieces);
  });

  test('a blunder into mate counts as a king-safety miss, not a hanging piece', () {
    final found = findWeaknesses([allowsMate(), allowsMate()]);
    expect(kind(found, WeaknessKind.walkingIntoMate)!.games.values, everyElement(2));
    expect(kind(found, WeaknessKind.hangingPieces), isNull);
  });

  test('a pattern in one game is not a habit', () {
    expect(findWeaknesses([allowsMate(), hangsKnight()]), isEmpty);
  });

  test('an opponent\'s blunder given straight back', () {
    final found = findWeaknesses([missesQueen(), missesQueen()]);
    final missed = kind(found, WeaknessKind.missedChances)!;
    expect(missed.detail, 'You let 2 of their 2 blunders go unpunished.');
    expect(missed.games.values, everyElement(4));
  });

  test('draws and losses after being well ahead', () {
    final found = findWeaknesses([missesQueen(), missesQueen()]);
    expect(kind(found, WeaknessKind.slippedWins)!.games, hasLength(2));
  });

  test('blunders bunched in one phase', () {
    final found = findWeaknesses([hangsKnight(), hangsKnight(), hangsKnight()]);
    final phase = kind(found, WeaknessKind.phaseBlunders)!;
    expect(phase.title, 'Blunders in the opening');
    expect(phase.detail, '3 of your 3 blunders came in the opening.');
  });

  test('an opening that keeps losing, named by its moves when it has no name', () {
    final found = findWeaknesses([hangsKnight(), hangsKnight(), hangsKnight()]);
    final opening = kind(found, WeaknessKind.losingOpening)!;
    expect(opening.title, 'Games starting 1. e4 e5 as White');
    expect(opening.detail, 'You scored 0% over 3 games.');
  });

  test('losses on time need no review', () {
    final found = findWeaknesses([
      game('1. e4 e5', endReason: 'timeout'),
      game('1. d4 d5', endReason: 'timeout'),
      game('1. c4 c5'),
    ]);
    final time = kind(found, WeaknessKind.timeLosses)!;
    expect(time.detail, '2 of your 3 losses were on time.');
    expect(time.share, closeTo(2 / 3, 1e-9));
  });

  test('the most widespread comes first', () {
    final found = findWeaknesses([
      allowsMate(),
      allowsMate(),
      hangsKnight(),
      hangsKnight(),
      hangsKnight(),
    ]);
    expect(found.first.share, greaterThanOrEqualTo(found.last.share));
    expect(found.map((w) => w.kind), contains(WeaknessKind.walkingIntoMate));
  });
}
