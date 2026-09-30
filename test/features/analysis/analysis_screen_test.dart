import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/engine/uci.dart';
import 'package:move_wise/features/analysis/analysis_screen.dart';
import 'package:move_wise/features/analysis/domain/analysis_args.dart';

import '../../support/fake_engine.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeEngine engine;

  setUp(() {
    // Three lines, White a little better, with win/draw/loss chances.
    engine = FakeEngine(
      reply: (fen) {
        final position = Chess.fromSetup(Setup.parseFen(fen));
        final moves = [
          for (final entry in position.legalMoves.entries)
            for (final to in entry.value.squares) NormalMove(from: entry.key, to: to).uci,
        ];
        return [
          for (var i = 0; i < 3 && i < moves.length; i++)
            EngineLine(
              rank: i + 1,
              depth: 16,
              score: EngineScore.centipawns(position.turn == Side.white ? 40 - i * 10 : -40),
              pv: [moves[i]],
              wdl: (win: 340, draw: 550, loss: 110),
            ),
        ];
      },
    );
  });

  Future<void> pump(WidgetTester tester, AnalysisArgs args) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => AnalysisScreen(args: args),
        ),
        GoRoute(path: '/coach', builder: (_, state) => Text('coach ${state.uri.query}')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chessEngineProvider.overrideWithValue(engine)],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a scanned position: Stockfish’s eval, chances and lines', (tester) async {
    await pump(tester, AnalysisArgs(fen: Chess.initial.fen, source: AnalysisSource.scan));

    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('From your scan · White to move'), findsOneWidget);
    expect(find.text('White 34%'), findsOneWidget);
    expect(find.text('Draw 55% · Black 11%'), findsOneWidget);
    expect(find.text('+0.4'), findsWidgets); // The bar and the first line.
    expect(find.text('+0.3'), findsOneWidget);
    // The depth Stockfish reached (the fake stops at 16).
    expect(find.textContaining('depth 16'), findsOneWidget);
    expect(find.text('Position from scan · White to move'), findsOneWidget);
  });

  testWidgets('tapping a move in a line plays it, and the list shows it', (tester) async {
    await pump(tester, AnalysisArgs(fen: Chess.initial.fen, source: AnalysisSource.scan));
    // The fake engine's best move: the first legal one.
    final best = Move.parse(FakeEngine.firstLegalMove(Chess.initial.fen))!;
    final san = Chess.initial.makeSan(best).$2;
    await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text(san)).first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1. $san'), findsOneWidget); // The stepper.
    expect(find.text('main line · Black to play'), findsOneWidget);

    await tester.tap(find.byTooltip('Back one move'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('from a game: opens at the move given, with the game as the main line', (
    tester,
  ) async {
    await pump(
      tester,
      AnalysisArgs(
        fen: Chess.initial.fen,
        moves: const ['e2e4', 'e7e5', 'g1f3'],
        ply: 2,
        source: AnalysisSource.game,
      ),
    );
    expect(find.text('From your game · after 1… e5'), findsOneWidget);
    expect(find.text('1… e5'), findsOneWidget);
    expect(find.text('Nf3'), findsOneWidget);
  });

  testWidgets('the engine switch turns Stockfish off', (tester) async {
    await pump(tester, AnalysisArgs(fen: Chess.initial.fen));
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('The engine is off. Turn it on to see Stockfish’s best lines.'),
      findsOneWidget,
    );
  });

  testWidgets('Ask AI Coach sends the position', (tester) async {
    await pump(tester, AnalysisArgs(fen: Chess.initial.fen));
    await tester.tap(find.byTooltip('Ask AI Coach about this position'));
    await tester.pumpAndSettle();
    expect(find.textContaining('coach q='), findsOneWidget);
  });
}
