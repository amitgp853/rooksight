// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/storage/analysis_repository.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/engine/engine_provider.dart';
import 'package:rooksight/features/games/games_screen.dart';
import 'package:rooksight/features/stats/bulk_review_controller.dart';
import 'package:rooksight/features/stats/stats_screen.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';
import '../coach/coach_fixtures.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;
  late FakeEngine engine;

  setUp(() {
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
    engine = FakeEngine();
  });

  /// Two reviewed Fool's mates (a habit) and one unreviewed Sicilian.
  Future<void> addGames() async {
    for (var i = 0; i < 2; i++) {
      analyses.analyses[await games.save(foolsMate)] = foolsMateAnalysis;
    }
    await games.save(sicilianWin);
  }

  Future<void> pumpStats(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/stats',
      routes: [
        GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
        GoRoute(
          path: '/games',
          builder: (context, state) => GamesScreen(
            title: state.uri.queryParameters['title'],
            only: GamesScreen.parseIds(state.uri.queryParameters['ids']),
          ),
        ),
        GoRoute(
          path: '/coach',
          builder: (context, state) => Text('Coach: ${state.uri.queryParameters['q']}'),
        ),
        GoRoute(
          path: '/review/:id',
          builder: (context, state) =>
              Text('Review ${state.pathParameters['id']} at ${state.uri.queryParameters['ply']}'),
        ),
        GoRoute(path: '/play', builder: (context, state) => const Text('Play')),
        GoRoute(path: '/import', builder: (context, state) => const Text('Import')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(games),
          analysisRepositoryProvider.overrideWithValue(analyses),
          chessEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('with no games it points to Play and Import', (tester) async {
    await pumpStats(tester);
    expect(find.text('No games yet'), findsOneWidget);
    await tester.tap(find.text('Import games'));
    await tester.pumpAndSettle();
    expect(find.text('Import'), findsOneWidget);
  });

  testWidgets('weaknesses, blunders by phase and results by opening', (tester) async {
    await addGames();
    await pumpStats(tester);

    await scrollTo(tester, find.text('Missing threats to your king'));
    expect(find.text('Top 3 weaknesses'), findsOneWidget);
    expect(find.text('In 2 games, a move of yours allowed a forced mate.'), findsOneWidget);

    await scrollTo(tester, find.text('Blunders by game phase'));
    expect(find.text('2 total'), findsOneWidget);
    expect(
      find.text('Most of your blunders come early, before your pieces are out.'),
      findsOneWidget,
    );

    await scrollTo(tester, find.text('Sicilian Defense'));
    final bar = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '1 wins, 0 draws, 0 losses',
    );
    expect(tester.getSize(bar).height, 10, reason: 'the win/draw/loss bar shows');
    expect(find.text('as Black · 1 game'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('as White · 2 games'), findsOneWidget);
  });

  testWidgets('See N games lists just those, each opening at the move', (tester) async {
    await addGames();
    await pumpStats(tester);
    await scrollTo(tester, find.text('See 2 games'));
    await tester.tap(find.text('See 2 games'));
    await tester.pumpAndSettle();

    expect(find.text('Missing threats to your king'), findsOneWidget);
    expect(find.text('Stockfish 1600'), findsNWidgets(2));
    expect(find.text('magnus_fan'), findsNothing);

    await tester.tap(find.text('Stockfish 1600').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('at 3'), findsOneWidget);
  });

  testWidgets('Ask coach opens the coach with the question ready', (tester) async {
    await addGames();
    await pumpStats(tester);
    await scrollTo(tester, find.text('Ask AI Coach'));
    await tester.tap(find.text('Ask AI Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Coach: How do I spot threats against my king in time?'), findsOneWidget);
  });

  testWidgets('the period switch limits the games', (tester) async {
    await addGames();
    await pumpStats(tester);
    expect(find.text('Your 3 most recent games · 2 reviewed'), findsOneWidget);
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('All 3 of your games · 2 reviewed'), findsOneWidget);
  });

  testWidgets('unreviewed games can be reviewed from here, without AI', (tester) async {
    await addGames();
    await pumpStats(tester);
    expect(find.text('1 game isn’t reviewed yet'), findsOneWidget);

    await tester.tap(find.text('Review it'));
    await tester.pumpAndSettle();

    final id = games.games.entries.firstWhere((e) => e.value == sicilianWin).key;
    expect(analyses.analyses[id]?.complete, isTrue);
    expect(analyses.analyses[id]!.depth, BulkReviewController.depth);
    expect(find.text('1 game isn’t reviewed yet'), findsNothing);
  });

  testWidgets('a stopped bulk review keeps what it did', (tester) async {
    await addGames();
    engine.delay = const Duration(milliseconds: 100);
    await pumpStats(tester);
    await tester.tap(find.text('Review it'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Reviewing game 1 of 1'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('1 game isn’t reviewed yet'), findsOneWidget);

    final id = games.games.entries.firstWhere((e) => e.value == sicilianWin).key;
    final partial = analyses.analyses[id]!;
    expect(partial.complete, isFalse);
    expect(partial.evals, isNotEmpty, reason: 'picked up again next time');
  });

  test('game ids and moves read back from the link', () {
    expect(GamesScreen.parseIds('5-23,7,x'), {5: 23, 7: null});
    expect(GamesScreen.parseIds(''), isNull);
  });
}
