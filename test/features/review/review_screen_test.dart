import 'dart:convert';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/board/move_wise_board.dart';
import 'package:move_wise/core/llm/gemini_client.dart';
import 'package:move_wise/core/llm/llm_client.dart';
import 'package:move_wise/core/storage/analysis_repository.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/engine/uci.dart';
import 'package:move_wise/features/review/review_screen.dart';
import 'package:move_wise/features/review/widgets/eval_bar.dart';
import 'package:move_wise/features/review/widgets/key_moment_card.dart';
import 'package:move_wise/features/review/widgets/move_table.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';
import '../../support/fake_llm.dart';

/// Fool's mate played as White: 1. f3 e5 2. g4?? Qh4#.
final foolsMate = GameRecord(
  source: GameSource.stockfish,
  pgn: '[Result "0-1"]\n\n1. f3 e5 2. g4 Qh4# 0-1',
  playerSide: Side.white,
  result: '0-1',
  endReason: 'checkmate',
  engineElo: 1600,
  opponentName: 'Stockfish 1600',
  plyCount: 4,
  startedAt: DateTime(2026, 9, 28),
  endedAt: DateTime(2026, 9, 28),
);

EngineLine sf(String uci, {int rank = 1, int? cp, int? mate}) => EngineLine(
  rank: rank,
  depth: 16,
  score: mate != null ? EngineScore.mate(mate) : EngineScore.centipawns(cp!),
  pv: [uci],
);

/// Scores from the side to move, per position of the game.
List<EngineLine> stockfish(String fen) => switch (fen.split(' ').first) {
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR' => [
    sf('e2e4', cp: 20),
    sf('d2d4', rank: 2, cp: 15),
  ],
  'rnbqkbnr/pppppppp/8/8/8/5P2/PPPPP1PP/RNBQKBNR' => [
    sf('e7e5', cp: 50),
    sf('d7d5', rank: 2, cp: 45),
  ],
  'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR' => [
    sf('d2d4', cp: -60),
    sf('e2e4', rank: 2, cp: -70),
  ],
  _ => [sf('d8h4', mate: 1), sf('d7d5', rank: 2, cp: 300)],
};

/// The position on the review board.
String boardFen(WidgetTester tester) =>
    tester.widget<MoveWiseBoard>(find.byType(MoveWiseBoard)).controller.fen;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;
  late FakeEngine engine;
  late FakeLlm llm;
  late bool hasKey;
  late int id;

  setUp(() async {
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
    engine = FakeEngine(reply: stockfish);
    llm = FakeLlm(
      reply: jsonEncode({
        'summary': 'A quick lesson in king safety.',
        'focus': ['Keep the pawns in front of your king at home early on.'],
        'verdict': 'Short and sharp.',
        'moments': [
          {
            'id': 2,
            'title': 'g4 opened the door to mate',
            'explanation': 'The queen now mates on h4.',
            'lesson': 'Every pawn move near your king opens a line to it.',
          },
        ],
      }),
    );
    hasKey = true;
    id = await games.save(foolsMate);
  });

  Future<void> pumpReview(WidgetTester tester, {String? gameId, int? initialPly}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(games),
          analysisRepositoryProvider.overrideWithValue(analyses),
          chessEngineProvider.overrideWithValue(engine),
          llmClientProvider.overrideWithValue(llm),
          llmConfiguredProvider.overrideWithValue(hasKey),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    ReviewScreen(gameId: gameId ?? '$id', initialPly: initialPly),
              ),
              GoRoute(
                path: '/coach',
                builder: (context, state) => Text('Coach ${state.uri.query}'),
              ),
              GoRoute(path: '/games', builder: (context, state) => const Text('games list')),
              GoRoute(
                path: '/analysis',
                builder: (context, state) => Text('analysis ${state.uri.query}'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the review until [finder] is built, then fully on screen.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('analyses the game, marks the moves and saves the result', (tester) async {
    await pumpReview(tester);

    // 4 of the 5 positions needed Stockfish; the mated one is known.
    expect(engine.searches, hasLength(4));
    expect(analyses.analyses[id]!.complete, isTrue);

    // Opens on the final position.
    expect(find.text('2…Qh4#'), findsOneWidget, reason: 'no ! once the game is decided');
    expect(find.text('Loss · 0–1'), findsOneWidget);
    expect(find.text('vs Stockfish 1600 · 2 moves'), findsOneWidget);

    await scrollTo(tester, find.text('2. g4 was a blunder'));
    expect(find.text('1. f3 was inaccurate'), findsOneWidget);
    expect(find.text('Blunder'), findsOneWidget);
  });

  testWidgets('a saved analysis is reused without Stockfish', (tester) async {
    await pumpReview(tester);
    engine.searches.clear();

    await pumpReview(tester);
    expect(engine.searches, isEmpty);
  });

  testWidgets('an interrupted analysis resumes where it stopped', (tester) async {
    analyses.analyses[id] = const StoredAnalysis(
      depth: 16,
      evals: [
        {
          'cp': 20,
          'pv': ['e2e4'],
          'cp2': 15,
        },
        {
          'cp': 50,
          'pv': ['e7e5'],
          'cp2': 45,
        },
      ],
      complete: false,
    );
    await pumpReview(tester);
    expect(engine.searches, hasLength(2), reason: 'two positions were left to search');
    expect(analyses.analyses[id]!.complete, isTrue);
  });

  testWidgets('steps through the game with the mark on the move', (tester) async {
    await pumpReview(tester);

    await tester.tap(find.byTooltip('Previous move'));
    await tester.pumpAndSettle();
    expect(find.text('2. g4??'), findsOneWidget);
    expect(find.text('move 2 of 2'), findsOneWidget);
    // Stepping scrolls the move strip, never the page: the header stays put.
    expect(tester.getTopLeft(find.textContaining('Loss · ')).dy, greaterThan(0));

    await tester.tap(find.byTooltip('First move'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('Analyze this position opens the analysis board at the move shown', (tester) async {
    await pumpReview(tester);
    await tester.tap(find.byTooltip('Previous move'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze position'));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.textContaining('analysis ')).data!;
    final query = Uri.splitQueryString(text.substring('analysis '.length));
    expect(query['from'], 'game');
    expect(query['ply'], '3');
    expect(query['moves'], 'f2f3,e7e5,g2g4,d8h4');
    expect(query['fen'], Chess.initial.fen);
  });

  testWidgets('any move shown can be asked about, not only key moments', (tester) async {
    await pumpReview(tester);
    await tester.tap(find.byTooltip('Previous move'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI about 2. g4'));
    await tester.pumpAndSettle();
    expect(find.text('Coach game=$id&move=2'), findsOneWidget);
  });

  group('many key moments', () {
    // 24 moves, every one a blunder: +3 for whoever is to move each time.
    final pawnWalk = GameRecord(
      source: GameSource.stockfish,
      pgn:
          '[Result "1/2-1/2"]\n\n1. a3 a6 2. b3 b6 3. c3 c6 4. d3 d6 5. e3 e6 6. f3 f6 '
          '7. g3 g6 8. h3 h6 9. a4 a5 10. b4 b5 11. c4 c5 12. d4 d5 1/2-1/2',
      playerSide: Side.white,
      result: '1/2-1/2',
      endReason: 'agreement',
      engineElo: 1600,
      opponentName: 'Stockfish 1600',
      plyCount: 24,
      startedAt: DateTime(2026, 9, 28),
      endedAt: DateTime(2026, 9, 28),
    );

    Future<void> pumpLong(WidgetTester tester) async {
      engine.reply = (fen) => [sf(FakeEngine.firstLegalMove(fen), cp: 300)];
      final long = await games.save(pawnWalk);
      await pumpReview(tester, gameId: '$long');
      await scrollTo(tester, find.text('Key moments'));
    }

    testWidgets('the 3 costliest are cards, the rest one-line rows behind Show all', (
      tester,
    ) async {
      await pumpLong(tester);
      expect(find.byType(KeyMomentCard), findsNWidgets(3));
      expect(find.byType(KeyMomentRow), findsNothing);
      await scrollTo(tester, find.text('Show all 24 moments'));
      await tester.tap(find.text('Show all 24 moments'));
      await tester.pumpAndSettle();
      // The review opens on the last move, itself a key moment: that one is
      // a full card, the other 20 are rows.
      expect(find.byType(KeyMomentRow), findsNWidgets(20));
      expect(find.byType(KeyMomentCard), findsNWidgets(4));

      // Only your moves, then only the opponent's.
      await scrollTo(tester, find.textContaining('Yours · '));
      await tester.tap(find.textContaining('Yours · '));
      await tester.pumpAndSettle();
      final yours = tester.widgetList<KeyMomentRow>(find.byType(KeyMomentRow));
      expect(yours.every((r) => r.mover == 'You'), isTrue);
      await tester.tap(find.textContaining('Opponent’s · '));
      await tester.pumpAndSettle();
      final theirs = tester.widgetList<KeyMomentRow>(find.byType(KeyMomentRow));
      expect(theirs.every((r) => r.mover == 'Stockfish'), isTrue);
      expect(yours.length + theirs.length, 20);

      await scrollTo(tester, find.text('Show fewer'));
      await tester.tap(find.text('Show fewer'));
      await tester.pumpAndSettle();
      expect(find.byType(KeyMomentRow), findsNothing);
    });

    testWidgets('a row opens as a full card once its move is on the board', (tester) async {
      await pumpLong(tester);
      await scrollTo(tester, find.text('Show all 24 moments'));
      await tester.tap(find.text('Show all 24 moments'));
      await tester.pumpAndSettle();
      final row = find.byType(KeyMomentRow).first;
      await scrollTo(tester, row);
      final tapped = tester.widget<KeyMomentRow>(row).move;
      await tester.tap(row);
      await tester.pumpAndSettle();
      // The board comes up; back to the list, where it's now a card.
      await tester.tap(find.text('Back to key moments'));
      await tester.pumpAndSettle();
      final rows = tester.widgetList<KeyMomentRow>(find.byType(KeyMomentRow));
      expect(rows.map((r) => r.move), isNot(contains(tapped)));
      expect(rows, hasLength(20));
    });

    testWidgets('the AI explains only the 3 costliest, in one request', (tester) async {
      await pumpLong(tester);
      expect(find.textContaining('Explains the 3 moments that cost most'), findsOneWidget);
      await scrollTo(tester, find.text('Explain key moments'));
      await tester.tap(find.text('Explain key moments'));
      await tester.pumpAndSettle();
      expect(llm.requests, hasLength(1));
      final prompt = llm.requests.single.messages.single.text;
      expect(RegExp('"id":').allMatches(prompt).length, 3);
    });
  });

  testWidgets('filters the move list by mark', (tester) async {
    await pumpReview(tester);
    final blunders = find.text('Blunders  1', findRichText: true);
    await scrollTo(tester, blunders);

    await tester.tap(blunders);
    await tester.pumpAndSettle();
    Finder inTable(String text) =>
        find.descendant(of: find.byType(MoveTable), matching: find.text(text));
    expect(inTable('2.'), findsOneWidget);
    expect(inTable('1.'), findsNothing, reason: 'row 1 has no blunder');
  });

  testWidgets('plays just the best move, then stops', (tester) async {
    await pumpReview(tester);
    await tester.tap(find.byTooltip('Previous move')); // 2. g4
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Play the best move'));
    await tester.tap(find.text('Play the best move'));
    // The page scrolls back to the board: one frame starts the animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Best move: 2. d4'), findsOneWidget);
    expect(find.text('instead of 2. g4'), findsOneWidget);

    // After the short pause the move plays, and nothing else follows.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Best move: 2. d4'), findsOneWidget);
    expect(boardFen(tester), startsWith('rnbqkbnr/pppp1ppp/8/4p3/3P4/5P2/'), reason: 'd4 played');

    await tester.tap(find.byTooltip('Back to the game'));
    await tester.pumpAndSettle();
    expect(find.text('Best move: 2. d4'), findsNothing);
  });

  testWidgets('an unknown game says so', (tester) async {
    await pumpReview(tester, gameId: '999');
    expect(find.text('This game couldn’t be found.'), findsOneWidget);
  });

  testWidgets('the eval bar follows the board', (tester) async {
    await pumpReview(tester);
    Finder bar(String label) =>
        find.descendant(of: find.byType(EvalBar), matching: find.text(label));

    expect(bar('0–1'), findsOneWidget, reason: 'White is mated');

    await tester.tap(find.byTooltip('Previous move')); // after 2. g4
    await tester.pumpAndSettle();
    expect(bar('M1'), findsOneWidget, reason: 'Black mates in one');

    await tester.tap(find.byTooltip('First move'));
    await tester.pumpAndSettle();
    expect(bar('0.2'), findsOneWidget);
  });

  testWidgets('key moments say who played the move', (tester) async {
    await pumpReview(tester);
    await scrollTo(tester, find.text('2. g4 was a blunder'));
    expect(find.text('You'), findsWidgets);
  });

  testWidgets('marked moves show their mark as text in a bordered chip', (tester) async {
    await pumpReview(tester);
    await scrollTo(tester, find.byType(MoveTable));
    expect(
      find.descendant(of: find.byType(MoveTable), matching: find.text('g4??', findRichText: true)),
      findsOneWidget,
    );
  });

  group('reading below the board', () {
    testWidgets('the key moment on the board is summed up under it', (tester) async {
      await pumpReview(tester);
      expect(find.byType(KeyMomentNote), findsNothing, reason: 'Qh4# is no key moment');

      await tester.tap(find.byTooltip('Previous move')); // 2. g4??
      await tester.pumpAndSettle();
      final note = find.byType(KeyMomentNote);
      expect(find.descendant(of: note, matching: find.text('2. g4 was a blunder')), findsOneWidget);
      expect(find.descendant(of: note, matching: find.text('Show best move')), findsOneWidget);

      final card = find.ancestor(
        of: find.text('2. g4 was a blunder', skipOffstage: false),
        matching: find.byType(KeyMomentCard, skipOffstage: false),
      );
      expect(tester.getBottomLeft(card).dy, greaterThan(844), reason: 'below the screen');

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(card);
      expect((rect.top > 0, rect.bottom <= 844), (true, true), reason: 'the whole card in view');
    });

    testWidgets('a tap below brings the board up, and the pill goes back', (tester) async {
      await pumpReview(tester);
      final table = find.byType(MoveTable);
      await scrollTo(tester, table);
      final before = tester.getTopLeft(table).dy;

      await tester.tap(find.descendant(of: table, matching: find.text('g4??', findRichText: true)));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.textContaining('Loss · ')).dy, greaterThan(0));
      expect(find.text('2. g4??'), findsOneWidget);

      // The note and the newly expanded card moved the table: it still returns.
      await tester.tap(find.text('Back to moves'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(table).dy, moreOrLessEquals(before, epsilon: 1));
      expect(find.text('Back to moves'), findsNothing);
    });

    testWidgets('the pill goes away once you scroll yourself', (tester) async {
      await pumpReview(tester);
      await scrollTo(tester, find.text('1. f3 was inaccurate'));
      await tester.tap(find.text('1. f3 was inaccurate'));
      await tester.pumpAndSettle();
      expect(find.text('Back to key moments'), findsOneWidget);

      await tester.drag(find.textContaining('Loss · '), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(find.text('Back to key moments'), findsNothing);
    });
  });

  group('explain key moments', () {
    testWidgets('without a key, says how to add one', (tester) async {
      hasKey = false;
      await pumpReview(tester);
      await scrollTo(tester, find.text('Want these explained in plain words?'));
      expect(find.text('Explain key moments'), findsNothing);
    });

    testWidgets('one call replaces the plain text, and is kept', (tester) async {
      await pumpReview(tester);
      await scrollTo(tester, find.text('Explain key moments'));
      await tester.tap(find.text('Explain key moments'));
      await tester.pumpAndSettle();

      expect(llm.requests, hasLength(1));
      expect(find.text('A quick lesson in king safety.'), findsOneWidget);
      expect(find.text('Keep the pawns in front of your king at home early on.'), findsOneWidget);
      await scrollTo(tester, find.textContaining('g4 opened the door to mate'));
      expect(find.text('Every pawn move near your king opens a line to it.'), findsOneWidget);
      // 1. f3 had no AI answer, so it keeps its plain description.
      expect(find.text('1. f3 was inaccurate'), findsOneWidget);
      expect(analyses.reviews[id]!.model, 'fake-model');

      // Reopening shows the saved words without asking again.
      await pumpReview(tester);
      await scrollTo(tester, find.textContaining('g4 opened the door to mate'));
      expect(llm.requests, hasLength(1));
    });

    testWidgets('the free-tier limit is explained, with a retry', (tester) async {
      llm.failure = const LlmRateLimited();
      await pumpReview(tester);
      await scrollTo(tester, find.text('Explain key moments'));
      await tester.tap(find.text('Explain key moments'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.textContaining('AI limit is used up'));
      llm.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('A quick lesson in king safety.'), findsOneWidget);
    });

    testWidgets('Explain again spends one more request', (tester) async {
      await pumpReview(tester);
      await scrollTo(tester, find.text('Explain key moments'));
      await tester.tap(find.text('Explain key moments'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Explain again'));
      await tester.tap(find.text('Explain again'));
      await tester.pumpAndSettle();
      expect(llm.requests, hasLength(2));
    });
  });

  testWidgets('Ask coach opens the coach about that move', (tester) async {
    await pumpReview(tester);
    await scrollTo(tester, find.text('Ask AI Coach about this move'));
    await tester.tap(find.text('Ask AI Coach about this move').first);
    await tester.pumpAndSettle();
    // The first card is the move that cost most: 2. g4?? (move index 2).
    expect(find.text('Coach game=$id&move=2'), findsOneWidget);
  });

  testWidgets('Ask coach about this game attaches the game', (tester) async {
    await pumpReview(tester);
    await tester.tap(find.byTooltip('Ask AI Coach about this game'));
    await tester.pumpAndSettle();
    expect(find.text('Coach game=$id'), findsOneWidget);
  });

  testWidgets('opens at a given move when asked', (tester) async {
    await pumpReview(tester, initialPly: 3);
    expect(boardFen(tester), startsWith('rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b'));
  });

  testWidgets('Delete game from the top bar, after asking, and back out', (tester) async {
    await pumpReview(tester);
    await tester.tap(find.byTooltip('Delete game'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this game?'), findsOneWidget);

    await tester.tap(find.text('Delete game'));
    await tester.pumpAndSettle();
    expect(games.games, isEmpty);
    expect(find.text('games list'), findsOneWidget);
  });

  group('your own line', () {
    /// Centre of [square] on the board, with White (the player) at the bottom.
    Offset squareCentre(WidgetTester tester, Square square) {
      final rect = tester.getRect(find.byType(Chessboard));
      final size = rect.width / 8;
      return rect.topLeft + Offset((square.file + 0.5) * size, (7 - square.rank + 0.5) * size);
    }

    Future<void> tapMove(WidgetTester tester, Square from, Square to) async {
      await tester.tapAt(squareCentre(tester, from));
      await tester.pump();
      await tester.tapAt(squareCentre(tester, to));
      await tester.pumpAndSettle();
    }

    Finder bar(String label) =>
        find.descendant(of: find.byType(EvalBar), matching: find.text(label));

    /// Positions the lines below reach, scored from the side to move.
    List<EngineLine> withLines(String fen) => switch (fen.split(' ').first) {
      // 1. e4 instead of 1. f3: Black to move, White a little better.
      'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR' => [sf('e7e5', cp: -30)],
      // 2. Kf2?? instead of 2. g4: Black to move and well ahead.
      'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPPKPP/RNBQ1BNR' => [sf('d8h4', cp: 500)],
      _ => stockfish(fen),
    };

    setUp(() => engine.reply = withLines);

    testWidgets('a different move starts your line; Stockfish scores it', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.byTooltip('First move'));
      await tester.pumpAndSettle();
      final searchesBefore = engine.searches.length;

      await tapMove(tester, Square.e2, Square.e4);

      expect(find.text('Your line · 1. e4'), findsOneWidget);
      expect(find.text('Good move · White +0.3'), findsOneWidget);
      expect(bar('0.3'), findsOneWidget, reason: 'the bar follows your line');
      expect(engine.searches.length, searchesBefore + 1);
      expect(boardFen(tester), startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b'));
    });

    testWidgets('stepping back and forth asks Stockfish nothing new', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.byTooltip('First move'));
      await tester.pumpAndSettle();
      await tapMove(tester, Square.e2, Square.e4);
      final searches = engine.searches.length;

      await tester.tap(find.byTooltip('Previous move'));
      await tester.pumpAndSettle();
      expect(find.text('Your line'), findsOneWidget);
      expect(find.text('from the start of the game'), findsOneWidget);

      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();
      expect(find.text('Your line · 1. e4'), findsOneWidget);
      expect(engine.searches.length, searches);

      await tester.tap(find.byTooltip('Back to the game'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('the move played in the game just goes forward', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.byTooltip('First move'));
      await tester.pumpAndSettle();

      await tapMove(tester, Square.f2, Square.f3);
      expect(find.textContaining('Your line'), findsNothing);
      expect(find.text('1. f3?!'), findsOneWidget);
    });

    testWidgets('a bad try is marked, with the best move', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.byTooltip('First move'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Next move'));
        await tester.pumpAndSettle();
      }

      await tapMove(tester, Square.e1, Square.f2);
      expect(find.text('Your line · 2. Kf2??'), findsOneWidget);
      expect(find.textContaining('Blunder · '), findsOneWidget);
      expect(find.textContaining('best was d4'), findsOneWidget);
    });

    testWidgets('Best move on the final checkmate: no best move, no blank page', (tester) async {
      await pumpReview(tester); // Opens on the last position: Black has mated.
      await tester.tap(find.text('Best move'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MoveWiseBoard), findsOneWidget);

      await tester.tap(find.byTooltip('Previous move'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MoveWiseBoard>(find.byType(MoveWiseBoard)).shapes.whereType<Arrow>(),
        isNotEmpty,
      );
    });

    testWidgets('the best-move arrow is off until asked for', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.byTooltip('First move'));
      await tester.pumpAndSettle();
      Set<Shape> shapes() => tester.widget<MoveWiseBoard>(find.byType(MoveWiseBoard)).shapes;
      expect(shapes().whereType<Arrow>(), isEmpty);

      await tester.tap(find.text('Best move'));
      await tester.pumpAndSettle();
      final arrow = shapes().whereType<Arrow>().single;
      expect((arrow.orig, arrow.dest), (Square.e2, Square.e4));
    });
  });
}
