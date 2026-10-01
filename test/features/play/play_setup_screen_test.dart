import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/features/play/domain/game_config.dart';
import 'package:move_wise/features/play/domain/game_session.dart';
import 'package:move_wise/features/play/domain/game_state.dart';
import 'package:move_wise/features/play/domain/unfinished_game.dart';
import 'package:move_wise/features/play/play_setup_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> pumpSetup(WidgetTester tester, {SettingsStore? store}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/play',
      routes: [
        GoRoute(path: '/play', builder: (_, _) => const PlaySetupScreen()),
        GoRoute(path: '/play/game', builder: (_, _) => const Text('game started')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store ?? SettingsStore.inMemory())],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PlaySetupScreen)));
  }

  testWidgets('defaults to Stockfish 1600, White, Rapid 10+0', (tester) async {
    await pumpSetup(tester);
    expect(find.text('1600'), findsOneWidget);
    expect(find.text('Club player'), findsOneWidget);
    expect(find.text('Stockfish 1600 · you play White · your clock 10+0'), findsOneWidget);
  });

  testWidgets('steps Elo by 200 and stops at the ends', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.byTooltip('Increase by 200'));
    await tester.pump();
    expect(find.text('1800'), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('Increase by 200'));
      await tester.pump();
    }
    expect(find.text('3000'), findsWidgets);
    expect(find.text('Super-GM'), findsOneWidget);
  });

  testWidgets('Start game saves the choices and opens the game', (tester) async {
    final container = await pumpSetup(tester);

    await tester.tap(find.byTooltip('Decrease by 200'));
    await tester.tap(find.text('Black'));
    await tester.tap(find.text('5+0'));
    await tester.pump();
    expect(find.text('Stockfish 1400 · you play Black · your clock 5+0'), findsOneWidget);

    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    final config = container.read(gameConfigProvider);
    expect(config.level.elo, 1400);
    expect(config.playerSide, Side.black);
    expect(config.timeControl.label, '5+0');
    expect(find.text('game started'), findsOneWidget);
  });

  group('with an unfinished game', () {
    Future<(ProviderContainer, SettingsStore)> pumpWithSavedGame(WidgetTester tester) async {
      final store = SettingsStore.inMemory();
      final game = GameState.start().play(Move.parse('e2e4')!)!;
      final session = GameSession(config: GameConfig.initial, game: game);
      UnfinishedGameStore.write(store, session, DateTime(2026));
      return (await pumpSetup(tester, store: store), store);
    }

    testWidgets('Start game asks first, and Keep it stays', (tester) async {
      final (container, _) = await pumpWithSavedGame(tester);
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      expect(find.text('Abandon your current game?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(find.text('game started'), findsNothing);
      expect(container.read(unfinishedGameProvider), isNotNull);
    });

    testWidgets('Start new drops it and starts', (tester) async {
      final (container, _) = await pumpWithSavedGame(tester);
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start new'));
      await tester.pumpAndSettle();
      expect(find.text('game started'), findsOneWidget);
      expect(container.read(unfinishedGameProvider), isNull);
    });
  });
}
