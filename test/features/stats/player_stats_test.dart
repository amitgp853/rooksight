import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/analysis_repository.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/features/play/domain/pgn_import.dart';
import 'package:rooksight/features/stats/domain/player_stats.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_game_repository.dart';
import '../coach/coach_fixtures.dart';

void main() {
  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;
  late int mateId;

  setUp(() async {
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
    mateId = await games.save(foolsMate);
    await games.save(sicilianWin);
    analyses.analyses[mateId] = foolsMateAnalysis;
  });

  test("opening names: Chess.com's family name, else the first moves", () {
    expect(openingName(sicilianWin, gameFromPgn(sicilianWin.pgn)), 'Sicilian Defense');
    expect(openingName(foolsMate, gameFromPgn(foolsMate.pgn)), '1. f3 e5');
    final lichess = GameRecord(
      source: GameSource.lichess,
      pgn: '[Opening "Alekhine Defense: Sämisch Attack"]\n\n1. e4 Nf6 *',
      playerSide: Side.white,
      result: '1-0',
      plyCount: 2,
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
    );
    expect(openingName(lichess, gameFromPgn(lichess.pgn)), 'Alekhine Defense');
  });

  test('results by opening cover every game; errors only reviewed ones', () async {
    final stats = PlayerStats.of(await loadStatsGames(games, analyses));

    expect(stats.games, 2);
    expect((stats.wins, stats.draws, stats.losses), (1, 0, 1));
    expect(stats.byOpening.map((o) => o.name), containsAll(['Sicilian Defense', '1. f3 e5']));

    expect(stats.reviewed, 1);
    expect(stats.blunders, 1);
    expect(stats.blundersPerGame, 1);
    expect(stats.errorsByPhase['opening'], (mistakes: 0, blunders: 1));
    expect(stats.worst.single.moment.index, 2);
  });

  test('a loss counts as "from a winning position" only after being 2+ up', () async {
    final stats = PlayerStats.of(await loadStatsGames(games, analyses));
    expect(stats.lossesFromWinning, 0);
  });

  test("a partial analysis doesn't count as reviewed", () async {
    analyses.analyses[mateId] = StoredAnalysis(
      depth: 16,
      complete: false,
      evals: foolsMateAnalysis.evals.take(2).toList(),
    );
    final stats = PlayerStats.of(await loadStatsGames(games, analyses));
    expect(stats.reviewed, 0);
    expect(stats.blundersPerGame, isNull);
  });
}
