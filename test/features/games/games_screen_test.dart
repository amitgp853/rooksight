import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/features/games/games_screen.dart';

import '../../support/fake_game_repository.dart';

GameRecord record(String result, {int elo = 1600, bool practice = false}) => GameRecord(
  source: GameSource.stockfish,
  pgn: '[Result "$result"]\n\n1. f3 e5 2. g4 Qh4# $result',
  playerSide: Side.white,
  result: result,
  endReason: 'checkmate',
  engineElo: elo,
  timeControl: '600+0',
  practice: practice,
  plyCount: 4,
  startedAt: DateTime(2026, 9, 28),
  endedAt: DateTime(2026, 9, 28),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpGames(WidgetTester tester, FakeGameRepository games) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/games',
      routes: [
        GoRoute(path: '/games', builder: (_, _) => const GamesScreen()),
        GoRoute(path: '/play', builder: (_, _) => const Text('setup')),
        GoRoute(
          path: '/review/:id',
          builder: (_, state) => Text('review ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameRepositoryProvider.overrideWithValue(games)],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty history points to a first game', (tester) async {
    await pumpGames(tester, FakeGameRepository());
    expect(find.text('No games yet'), findsOneWidget);

    await tester.tap(find.text('Play vs Computer'));
    await tester.pumpAndSettle();
    expect(find.text('setup'), findsOneWidget);
  });

  testWidgets('lists games with result, ending and details', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('0-1', elo: 800, practice: true));
    await pumpGames(tester, games);

    expect(find.text('L'), findsOneWidget);
    expect(find.text('Stockfish 800'), findsOneWidget);
    expect(find.text('Checkmate · 2 moves · 10+0 · Practice'), findsOneWidget);
  });

  testWidgets('each game says where it came from', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('1-0'));
    await games.saveAllNew([
      GameRecord(
        source: GameSource.chesscom,
        externalId: 'https://www.chess.com/game/live/1',
        pgn: '1. e4 e5 *',
        playerSide: Side.white,
        result: '1-0',
        opponentName: 'opponent42',
        opponentRating: 1544,
        timeClass: 'blitz',
        timeControl: '180+2',
        plyCount: 2,
        startedAt: DateTime(2026, 9, 27),
        endedAt: DateTime(2026, 9, 27),
      ),
    ]);
    await pumpGames(tester, games);

    expect(find.text('MoveWise'), findsOneWidget);
    expect(find.text('Chess.com'), findsOneWidget);
    expect(find.text('opponent42 (1544)'), findsOneWidget);
    expect(find.text('2 moves · 3+2'), findsNothing, reason: '1 move pair here');
  });

  testWidgets('tapping a game opens its review', (tester) async {
    final games = FakeGameRepository();
    final id = await games.save(record('0-1'));
    await pumpGames(tester, games);

    await tester.tap(find.text('Stockfish 1600'));
    await tester.pumpAndSettle();
    expect(find.text('review $id'), findsOneWidget);
  });

  testWidgets('All, Won and Lost tabs pick the games', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('1-0', elo: 800));
    await games.save(record('0-1', elo: 1200));
    await games.save(record('1/2-1/2', elo: 1600));
    await pumpGames(tester, games);

    expect(find.byType(Card), findsNWidgets(3));

    await tester.tap(find.text('Won'));
    await tester.pumpAndSettle();
    expect(find.text('Stockfish 800'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);

    await tester.tap(find.text('Lost'));
    await tester.pumpAndSettle();
    expect(find.text('Stockfish 1200'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNWidgets(3), reason: 'draws only under All');
  });

  testWidgets('a tab with no games says so', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('0-1'));
    await pumpGames(tester, games);
    await tester.tap(find.text('Won'));
    await tester.pumpAndSettle();
    expect(find.text('No wins here yet.'), findsOneWidget);
  });

  testWidgets('swipe left, confirm, and the game is gone', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('1-0', elo: 800));
    await games.save(record('0-1', elo: 1200));
    await pumpGames(tester, games);

    await tester.drag(find.text('Stockfish 800'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete this game?'), findsOneWidget);
    expect(find.text('vs Stockfish 800'), findsOneWidget, reason: 'the sheet shows which game');
    await tester.tap(find.text('Delete game'));
    await tester.pumpAndSettle();

    expect(find.text('Stockfish 800'), findsNothing);
    expect(find.text('Stockfish 1200'), findsOneWidget);
    expect(games.games, hasLength(1));
  });

  testWidgets('cancelling keeps the game', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('1-0', elo: 800));
    await pumpGames(tester, games);

    await tester.drag(find.text('Stockfish 800'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Stockfish 800'), findsOneWidget);
    expect(games.games, hasLength(1));
  });

  testWidgets('long-press offers to delete too', (tester) async {
    final games = FakeGameRepository();
    await games.save(record('1-0', elo: 800));
    await pumpGames(tester, games);

    await tester.longPress(find.text('Stockfish 800'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete game'));
    await tester.pumpAndSettle();
    expect(games.games, isEmpty);
  });
}
