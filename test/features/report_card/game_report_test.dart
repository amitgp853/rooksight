// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/engine/uci.dart';
import 'package:rooksight/features/play/domain/pgn_import.dart';
import 'package:rooksight/features/report_card/domain/game_report.dart';
import 'package:rooksight/features/review/domain/game_analysis.dart';
import 'package:rooksight/features/review/domain/move_review.dart';
import 'package:rooksight/features/review/domain/position_eval.dart';

import '../coach/coach_fixtures.dart';

GameReport foolsMateReport({String? aiVerdict}) {
  final game = gameFromPgn(foolsMate.pgn);
  final analysis = GameAnalysis(game, foolsMateAnalysis.evals.map(PositionEval.fromJson).toList());
  return GameReport.of(SavedGame(1, foolsMate), analysis, aiVerdict: aiVerdict);
}

void main() {
  test('the worst blunder, marked on its square', () {
    final worst = foolsMateReport().worst!;
    expect(worst.label, '2. g4??');
    expect(worst.quality, MoveQuality.blunder);
    expect(worst.mark, Square.g4);
    expect(worst.fen, startsWith('rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b'));
  });

  test('no move of the player\'s matched Stockfish: no best move', () {
    expect(foolsMateReport().best, isNull);
  });

  test('a "one good move" is the best move', () {
    const pgn = '[Result "1-0"]\n\n1. e4 e5';
    final game = gameFromPgn(pgn);
    final analysis = GameAnalysis(game, const [
      // 1. e4 was a full pawn better than anything else.
      PositionEval(
        score: EngineScore.centipawns(30),
        secondScore: EngineScore.centipawns(-100),
        bestLine: ['e2e4'],
      ),
      PositionEval(score: EngineScore.centipawns(-30), bestLine: ['e7e5']),
      PositionEval(score: EngineScore.centipawns(30), bestLine: ['g1f3']),
    ]);
    final record = GameRecord(
      source: GameSource.stockfish,
      pgn: pgn,
      playerSide: Side.white,
      result: '1-0',
      plyCount: 2,
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
    );
    final report = GameReport.of(SavedGame(1, record), analysis);
    expect(report.best!.label, '1. e4!');
    expect(report.worst, isNull);
  });

  test('the context line: opponent, time control, opening', () {
    expect(foolsMateReport().context, 'vs Stockfish 1600 · 1. f3 e5');
  });

  test('the AI verdict when there is one, else one from the numbers', () {
    final plain = foolsMateReport();
    expect(plain.aiVerdict, isFalse);
    expect(plain.verdict, 'One blunder on move 2 turned the game; 1 blunder in all.');

    final ai = foolsMateReport(aiVerdict: 'A short, sharp lesson.');
    expect(ai.aiVerdict, isTrue);
    expect(ai.verdict, 'A short, sharp lesson.');
  });

  test('plain verdicts', () {
    expect(plainVerdict(PlayerOutcome.win, 91.2, 0), 'A clean win: 91% accuracy and no blunders.');
    expect(
      plainVerdict(PlayerOutcome.win, 80, 2),
      'A win at 80% accuracy, with 2 blunders to tidy up.',
    );
    expect(plainVerdict(PlayerOutcome.loss, 85, 0), 'A close fight: 85% accuracy and no blunders.');
    expect(plainVerdict(PlayerOutcome.draw, 70, 1), 'A draw at 70% accuracy, with 1 blunder.');
  });
}
