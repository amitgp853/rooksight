import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/storage/analysis_repository.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/features/home/home_screen.dart';
import 'package:move_wise/features/pass_play/domain/pass_config.dart';
import 'package:move_wise/features/pass_play/domain/pass_session.dart';
import 'package:move_wise/features/pass_play/domain/unfinished_pass_game.dart';
import 'package:move_wise/features/play/domain/game_clock.dart';
import 'package:move_wise/features/play/domain/game_config.dart';
import 'package:move_wise/features/play/domain/game_session.dart';
import 'package:move_wise/features/play/domain/game_state.dart';
import 'package:move_wise/features/play/domain/unfinished_game.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_game_repository.dart';
import '../coach/coach_fixtures.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late SettingsStore store;
  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;

  setUp(() {
    store = SettingsStore.inMemory();
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
  });

  /// Saves an unfinished game: 1. e4, Black to move, 8:42 left for White.
  void saveUnfinishedGame() {
    final game = GameState.start().play(Move.parse('e2e4')!)!;
    UnfinishedGameStore.write(
      store,
      GameSession(
        config: GameConfig.initial,
        game: game,
        clock: GameClock.stopped(
          white: const Duration(minutes: 8, seconds: 42),
          black: const Duration(minutes: 10),
          increment: Duration.zero,
          owner: Side.white,
        ),
      ),
      DateTime(2026),
    );
  }

  Future<ProviderContainer> pumpHome(WidgetTester tester, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        for (final path in [
          '/play',
          '/play/game',
          '/pass',
          '/pass/game',
          '/scan',
          '/import',
          '/coach',
          '/stats',
          '/games',
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(appBar: AppBar(), body: Text('route $path')),
          ),
        GoRoute(path: '/settings', builder: (_, _) => const Text('route /settings')),
        GoRoute(path: '/debug/design-system', builder: (_, _) => const Text('debug')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          gameRepositoryProvider.overrideWithValue(games),
          analysisRepositoryProvider.overrideWithValue(analyses),
        ],
        child: MaterialApp.router(theme: theme ?? AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  testWidgets('no unfinished game: no Continue card, Play first', (tester) async {
    await pumpHome(tester);
    expect(find.text('CONTINUE GAME'), findsNothing);
    expect(find.text('Play vs Computer'), findsOneWidget);
    expect(find.text('Import Games'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });

  testWidgets('an unfinished game shows, and Resume asks the game to continue', (tester) async {
    saveUnfinishedGame();
    final container = await pumpHome(tester);

    expect(find.text('CONTINUE GAME'), findsOneWidget);
    expect(find.text('vs Stockfish · 1600'), findsOneWidget);
    expect(find.text('Rapid 10+0 · move 1'), findsOneWidget);
    expect(find.text('08:42 · Stockfish to move'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('route /play/game'), findsOneWidget);
    expect(container.read(resumeGameProvider).take(), isTrue);
  });

  testWidgets('Pass & play opens its setup', (tester) async {
    await pumpHome(tester);
    expect(find.text('Two players, one phone'), findsOneWidget);
    await tester.tap(find.text('Pass & Play'));
    await tester.pumpAndSettle();
    expect(find.text('route /pass'), findsOneWidget);
  });

  testWidgets('Scan a board opens the camera', (tester) async {
    await pumpHome(tester);
    expect(find.text('Photo of a real board or a book diagram'), findsOneWidget);
    await tester.tap(find.text('Scan a board'));
    await tester.pumpAndSettle();
    expect(find.text('route /scan'), findsOneWidget);
  });

  testWidgets('the most recently left game is the one to continue', (tester) async {
    saveUnfinishedGame(); // Saved at 2026-01-01.
    final game = GameState.start().play(Move.parse('e2e4')!)!;
    UnfinishedPassGameStore.write(
      store,
      PassSession(
        config: PassConfig.initial.copyWith(secondName: 'Ann'),
        game: game,
        clock: GameClock.stopped(
          white: const Duration(minutes: 9),
          black: const Duration(minutes: 10),
          increment: Duration.zero,
        ),
      ),
      DateTime(2026, 1, 2),
    );
    final container = await pumpHome(tester);

    expect(find.text('You vs Ann'), findsOneWidget);
    expect(find.text('Pass & Play · Rapid 10+5 · move 1'), findsOneWidget);
    expect(find.text('10:00 · Ann to move'), findsOneWidget);
    expect(find.text('vs Stockfish · 1600'), findsNothing);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('route /pass/game'), findsOneWidget);
    expect(container.read(resumePassGameProvider).take(), isTrue);
  });

  testWidgets('the Continue card fits long names and a large system font', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    UnfinishedPassGameStore.write(
      store,
      PassSession(
        config: PassConfig.initial.copyWith(
          firstName: 'Alexandrina Kov',
          secondName: 'Opponent Name',
        ),
        game: GameState.start().play(Move.parse('e2e4')!)!,
        clock: GameClock.stopped(
          white: const Duration(minutes: 9),
          black: const Duration(minutes: 10),
          increment: const Duration(seconds: 5),
        ),
      ),
      DateTime(2026, 1, 2),
    );
    await pumpHome(tester);

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('the top weakness from the last 20 games', (tester) async {
    for (var i = 0; i < 2; i++) {
      analyses.analyses[await games.save(foolsMate)] = foolsMateAnalysis;
    }
    await pumpHome(tester);
    await tester.scrollUntilVisible(find.text('TOP WEAKNESS'), 200);
    expect(
      find.text(
        'Missing threats to your king — In 2 games, a move of yours allowed a forced mate.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without a pattern yet, it says what to do', (tester) async {
    await pumpHome(tester);
    await tester.scrollUntilVisible(find.text('TOP WEAKNESS'), 200);
    expect(find.text('Review a few games to find your patterns.'), findsOneWidget);
  });

  testWidgets('the cards lead to their screens', (tester) async {
    await pumpHome(tester);
    for (final (label, route) in [
      ('Play vs Computer', '/play'),
      ('Import Games', '/import'),
      ('AI Coach', '/coach'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('route $route'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('light mode outlines the cards', (tester) async {
    await pumpHome(tester, theme: AppTheme.light());
    final card = tester.widget<Material>(
      find.ancestor(of: find.text('Import Games'), matching: find.byType(Material)).first,
    );
    final side = (card.shape! as RoundedRectangleBorder).side;
    expect(side.style, BorderStyle.solid);
  });
}
