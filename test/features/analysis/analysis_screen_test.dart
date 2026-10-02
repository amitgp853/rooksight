// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/storage/saved_position_repository.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/engine/engine_provider.dart';
import 'package:rooksight/engine/uci.dart';
import 'package:rooksight/features/analysis/analysis_screen.dart';
import 'package:rooksight/features/analysis/domain/analysis_args.dart';

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

  late MemorySavedPositionRepository positions;
  setUp(() => positions = MemorySavedPositionRepository());

  Future<void> pump(WidgetTester tester, AnalysisArgs args, {SavedPosition? saved}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Column(
            children: [
              Expanded(
                child: AnalysisScreen(args: args, saved: saved),
              ),
              // Leaves the board, as Back would.
              Builder(
                builder: (context) =>
                    TextButton(onPressed: () => context.go('/away'), child: const Text('leave')),
              ),
            ],
          ),
        ),
        GoRoute(path: '/away', builder: (_, _) => const Text('away')),
        GoRoute(path: '/coach', builder: (_, state) => Text('coach ${state.uri.query}')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chessEngineProvider.overrideWithValue(engine),
          savedPositionRepositoryProvider.overrideWithValue(positions),
        ],
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

  testWidgets('the eval bar keeps its reading until the next position has one', (tester) async {
    await pump(tester, AnalysisArgs(fen: Chess.initial.fen, source: AnalysisSource.scan));
    expect(find.text('White 34%'), findsOneWidget);

    // Stockfish is slow on the next position, and finds Black better there.
    engine
      ..delay = const Duration(seconds: 1)
      ..reply = (fen) => [
        EngineLine(
          rank: 1,
          depth: 16,
          score: const EngineScore.centipawns(150),
          pv: [FakeEngine.firstLegalMove(fen)],
          wdl: (win: 600, draw: 300, loss: 100),
        ),
      ];
    final best = Move.parse(FakeEngine.firstLegalMove(Chess.initial.fen))!;
    final san = Chess.initial.makeSan(best).$2;
    await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text(san)).first);
    await tester.pump(const Duration(milliseconds: 300));
    // Not snapped to level: the last reading stays.
    expect(find.text('White 34%'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('White 10%'), findsOneWidget); // Black to move, 60% Black.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('following a line into checkmate shows the mate, without errors', (tester) async {
    // Black to move plays b6, then White mates on the back rank.
    const fen = '6k1/1p3ppp/8/8/8/8/5PPP/R5K1 b - - 0 1';
    engine.reply = (fen) {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      if (position.turn == Side.black) {
        return [
          const EngineLine(
            rank: 1,
            depth: 24,
            score: EngineScore.mate(-1),
            pv: ['b7b6', 'a1a8'],
            wdl: (win: 0, draw: 0, loss: 1000),
          ),
        ];
      }
      return [
        const EngineLine(
          rank: 1,
          depth: 24,
          score: EngineScore.mate(1),
          pv: ['a1a8'],
          wdl: (win: 1000, draw: 0, loss: 0),
        ),
      ];
    };
    await pump(tester, const AnalysisArgs(fen: fen, source: AnalysisSource.setup));
    // Tap each move of the line in turn, as a player stepping along it.
    await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text('b6')).first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text('Ra8#')).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Checkmate. White wins.'), findsOneWidget);
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

  group('saving', () {
    /// Plays the first move of Stockfish's top line.
    Future<void> playBest(WidgetTester tester, Position position) async {
      final best = Move.parse(FakeEngine.firstLegalMove(position.fen))!;
      final san = position.makeSan(best).$2;
      await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.text(san)).first);
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('saves a scanned position, then keeps the moves explored', (tester) async {
      await pump(tester, AnalysisArgs(fen: Chess.initial.fen, source: AnalysisSource.scan));

      await tester.tap(find.byTooltip('Save position'));
      await tester.pumpAndSettle();
      expect(find.text('Save position'), findsOneWidget); // The dialog title.
      expect(find.textContaining('Scanned position · '), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Book diagram p. 42');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final saved = positions.all.single;
      expect(saved.title, 'Book diagram p. 42');
      expect(saved.fen, Chess.initial.fen);
      expect(saved.source, 'scan');
      expect(saved.moveCount, 0);
      expect(find.byTooltip('Saved'), findsOneWidget);

      await playBest(tester, Chess.initial);
      await tester.pump(const Duration(seconds: 1));
      expect(positions.all.single.moveCount, 1);
      expect(positions.all.single.path, [0]);
    });

    testWidgets('the ⋯ menu offers saving too', (tester) async {
      await pump(tester, AnalysisArgs(fen: Chess.initial.fen));
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('This position'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Save position'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(positions.all.single.title, startsWith('Position · '));
    });

    testWidgets('leaving right after a move still keeps it', (tester) async {
      await pump(tester, AnalysisArgs(fen: Chess.initial.fen));
      await tester.tap(find.byTooltip('Save position'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump(const Duration(milliseconds: 100));

      await playBest(tester, Chess.initial);
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();
      expect(find.text('away'), findsOneWidget);
      expect(positions.all.single.moveCount, 1);
    });

    testWidgets('reopens a saved position where it was left', (tester) async {
      final saved = SavedPosition(
        id: 7,
        title: 'Italian study',
        fen: Chess.initial.fen,
        moves: const [
          {
            'm': 'e2e4',
            'c': [
              {'m': 'e7e5'},
            ],
          },
        ],
        path: const [0, 0],
        source: 'scan',
        orientation: 'black',
        createdAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      );
      await pump(tester, AnalysisArgs(fen: Chess.initial.fen), saved: saved);

      expect(find.text('Italian study'), findsOneWidget);
      expect(find.text('1… e5'), findsOneWidget); // The stepper.
      expect(find.byTooltip('Saved'), findsOneWidget);
    });
  });
}
