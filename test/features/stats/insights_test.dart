import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/engine/uci.dart';
import 'package:move_wise/features/play/domain/pgn_import.dart';
import 'package:move_wise/features/review/domain/game_analysis.dart';
import 'package:move_wise/features/review/domain/position_eval.dart';
import 'package:move_wise/features/stats/domain/insights.dart';
import 'package:move_wise/features/stats/domain/player_stats.dart';
import 'package:move_wise/features/stats/widgets/insight_cards.dart';

import '../coach/coach_fixtures.dart';

var _id = 0;

/// A game ending [daysAgo] days before 1 Oct 2026, from the player's side.
StatsGame result(PlayerOutcome outcome, {int daysAgo = 0, int? rating, String? timeClass}) {
  final pgn = '[Result "*"]\n\n1. e4 e5';
  final record = GameRecord(
    source: GameSource.chesscom,
    pgn: pgn,
    playerSide: Side.white,
    result: switch (outcome) {
      PlayerOutcome.win => '1-0',
      PlayerOutcome.loss => '0-1',
      _ => '1/2-1/2',
    },
    playerRating: rating,
    timeClass: timeClass,
    plyCount: 2,
    startedAt: DateTime(2026, 10).subtract(Duration(days: daysAgo)),
    endedAt: DateTime(2026, 10).subtract(Duration(days: daysAgo)),
  );
  return StatsGame(SavedGame(++_id, record), gameFromPgn(pgn));
}

/// Fool's mate, reviewed: 2. g4?? on move 2.
StatsGame foolsMateGame() {
  final game = gameFromPgn(foolsMate.pgn);
  return StatsGame(
    SavedGame(++_id, foolsMate),
    game,
    GameAnalysis(game, foolsMateAnalysis.evals.map(PositionEval.fromJson).toList()),
  );
}

/// Won as White after being [down] pawns behind at the second position.
StatsGame comeback(double down) {
  const pgn = '[Result "1-0"]\n\n1. e4 e5 2. Nf3 Nc6';
  final game = gameFromPgn(pgn);
  final record = GameRecord(
    source: GameSource.stockfish,
    pgn: pgn,
    playerSide: Side.white,
    result: '1-0',
    plyCount: 4,
    startedAt: DateTime(2026),
    endedAt: DateTime(2026),
  );
  PositionEval cp(int c) => PositionEval(score: EngineScore.centipawns(c), bestLine: const []);
  return StatsGame(
    SavedGame(++_id, record),
    game,
    // Scores from the side to move: Black to move at ply 1 and 3.
    GameAnalysis(game, [cp(0), cp((down * 100).round()), cp(-50), cp(50), cp(200)]),
  );
}

void main() {
  test('errors by move number, in tens', () {
    final buckets = errorsByMoveNumber([foolsMateGame(), foolsMateGame()]);
    expect(buckets.map((b) => b.label), ['1–10', '11–20', '21–30', '31–40', '41+']);
    expect(buckets.first.blunders, 2);
    expect(
      moveTimingTakeaway(buckets),
      '100% of your mistakes and blunders come between moves 1 and 10.',
    );
  });

  test('personal bests: accuracy, comeback, streak, peak rating', () {
    final bests = PersonalBests.of([
      comeback(4.5),
      comeback(3.2),
      result(PlayerOutcome.win, rating: 1300, timeClass: 'rapid'),
      result(PlayerOutcome.loss, rating: 1320, timeClass: 'rapid'),
      foolsMateGame(),
    ]);
    expect(bests.biggestComeback!.value, 4.5);
    expect(bests.biggestComeback!.ply, 1);
    expect(bests.peakRating!.value, 1320);
    expect(bests.longestWinStreak, 3);
    // Fool's mate is too short to count for accuracy.
    expect(bests.bestAccuracy, isNull);
  });

  test('being only a little behind is no comeback', () {
    expect(PersonalBests.of([comeback(2)]).biggestComeback, isNull);
  });

  test('win rate', () {
    final stats = PlayerStats.of([result(PlayerOutcome.win), result(PlayerOutcome.loss)]);
    expect(winRate(stats), 50);
  });
}
