import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/llm/gemini_client.dart';
import 'package:move_wise/core/llm/llm_client.dart';
import 'package:move_wise/core/speech/speech_input.dart';
import 'package:move_wise/core/storage/analysis_repository.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/features/coach/coach_screen.dart';
import 'package:move_wise/features/coach/domain/coach_tools.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';
import '../../support/fake_llm.dart';
import '../../support/fake_speech_input.dart';
import 'coach_fixtures.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;
  late FakeLlm llm;
  late FakeEngine engine;
  late FakeSpeechInput speech;
  late bool hasKey;
  late int id;

  final answer = jsonEncode({
    'headline': 'You opened lines to your own king.',
    'body': '2. g4 allowed Qh4# at once.',
    'try_this': 'Keep the pawns in front of your king at home early on.',
    'move': {'game_id': 1, 'move_id': 2},
  });

  setUp(() async {
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
    id = await games.save(foolsMate);
    analyses.analyses[id] = foolsMateAnalysis;
    llm = FakeLlm(
      turns: [
        toolCall(CoachTools.getGameMistakes, {'game_id': id}),
      ],
      reply: answer,
    );
    engine = FakeEngine();
    speech = FakeSpeechInput();
    hasKey = true;
  });

  /// The coach at `/coach`, with the review route recording where it opened.
  Future<void> pumpCoach(WidgetTester tester, {String location = '/coach'}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/coach',
          builder: (context, state) => CoachScreen(
            gameId: int.tryParse(state.uri.queryParameters['game'] ?? ''),
            moveIndex: int.tryParse(state.uri.queryParameters['move'] ?? ''),
            question: state.uri.queryParameters['q'],
          ),
        ),
        GoRoute(
          path: '/review/:gameId',
          builder: (context, state) => Text(
            'Review ${state.pathParameters['gameId']} at ${state.uri.queryParameters['ply']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(games),
          analysisRepositoryProvider.overrideWithValue(analyses),
          chessEngineProvider.overrideWithValue(engine),
          llmClientProvider.overrideWithValue(llm),
          llmConfiguredProvider.overrideWithValue(hasKey),
          speechInputProvider.overrideWithValue(speech),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts with suggested questions', (tester) async {
    await pumpCoach(tester);
    expect(find.text('Ask the AI Coach'), findsOneWidget);
    expect(find.text('Why do I keep losing?'), findsOneWidget);
    expect(llm.requests, isEmpty);
  });

  testWidgets('without a key it says so and can\'t send', (tester) async {
    hasKey = false;
    await pumpCoach(tester);
    expect(find.text('The AI Coach isn’t set up on this device yet.'), findsOneWidget);
    expect(find.textContaining('.env'), findsNothing, reason: 'no developer wording');
    expect(find.text('Why do I keep losing?'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Hello?');
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward)).onPressed,
      isNull,
    );
  });

  testWidgets('a question shows the steps, then the checked answer', (tester) async {
    await pumpCoach(tester);
    await tester.tap(find.text('Why do I keep losing?'));
    await tester.pumpAndSettle();

    expect(find.text('Why do I keep losing?'), findsOneWidget); // The bubble.
    expect(find.text('WORKED THROUGH 2 STEPS'), findsOneWidget);
    expect(find.text('Your game vs Stockfish 1600'), findsOneWidget);
    expect(find.text('Writing your answer'), findsOneWidget);
    expect(find.text('You opened lines to your own king.'), findsOneWidget);
    expect(find.text('2. g4 allowed Qh4# at once.'), findsOneWidget);
    expect(find.text('2. g4?? → d4'), findsOneWidget);
    expect(llm.requests, hasLength(2));
  });

  testWidgets('the move card opens the review at that move', (tester) async {
    await pumpCoach(tester);
    await tester.tap(find.text('Why do I keep losing?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. g4?? → d4'));
    await tester.pumpAndSettle();
    expect(find.text('Review $id at 3'), findsOneWidget);
  });

  testWidgets('from a review: the question about the move is ready to send', (tester) async {
    await pumpCoach(tester, location: '/coach?game=$id&move=2');
    expect(find.text('About 2. g4'), findsOneWidget);
    expect(find.text('What went wrong with 2. g4, and what should I have played?'), findsOneWidget);
    expect(llm.requests, isEmpty);

    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(llm.requests.first.messages.last.text, contains('move_id 2 (2. g4)'));
    // The chip stays for follow-ups, and the question shows what it was about.
    expect(find.text('About 2. g4'), findsNWidgets(2));
  });

  testWidgets('a failed question explains why and can be asked again', (tester) async {
    llm.failure = const LlmRateLimited();
    await pumpCoach(tester);
    await tester.tap(find.text('Why do I keep losing?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI limit is used up'), findsOneWidget);

    llm.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI limit is used up'), findsNothing);
    expect(find.text('You opened lines to your own king.'), findsOneWidget);
  });

  testWidgets('New chat starts over', (tester) async {
    await pumpCoach(tester);
    await tester.tap(find.text('Why do I keep losing?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(find.text('Ask the AI Coach'), findsOneWidget);
  });

  testWidgets('steps show live while the coach works', (tester) async {
    engine.delay = const Duration(seconds: 2);
    llm.turns
      ..clear()
      ..add(toolCall(CoachTools.analyzePosition, {'fen': beforeG4}));
    llm.reply = jsonEncode({'headline': 'h', 'body': 'Fine.'});
    await pumpCoach(tester);
    await tester.tap(find.text('Why do I keep losing?'));
    await tester.pump();
    await tester.pump();

    expect(find.text('WORKING…'), findsOneWidget);
    expect(find.text('Asking Stockfish about this position…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward)).onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stockfish’s best move'), findsOneWidget);
    expect(find.text('Fine.'), findsOneWidget);
  });

  group('attaching a game', () {
    testWidgets('pick a game: its chip, game questions, and the AI told which', (tester) async {
      await games.save(sicilianWin);
      await pumpCoach(tester);

      await tester.tap(find.byTooltip('Attach a game'));
      await tester.pumpAndSettle();
      expect(find.text('Ask about a game'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget, reason: 'only Fool’s mate is');

      await tester.enterText(find.widgetWithText(TextField, 'Search by opponent'), 'stock');
      await tester.pumpAndSettle();
      expect(find.text('vs magnus_fan'), findsNothing);
      await tester.tap(find.text('vs Stockfish 1600'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Game: vs Stockfish 1600'), findsOneWidget);
      expect(find.text('What went wrong in this game?'), findsOneWidget);

      await tester.tap(find.text('What went wrong in this game?'));
      await tester.pumpAndSettle();
      expect(
        llm.requests.first.messages.last.text,
        contains('The question is about game $id: vs Stockfish 1600'),
      );
    });

    testWidgets('the game stays for follow-ups until removed', (tester) async {
      await pumpCoach(tester, location: '/coach?game=$id');
      expect(find.textContaining('Game: vs Stockfish 1600'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Where did it go wrong?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Game: vs Stockfish 1600'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Remove the game'));
      await tester.pumpAndSettle();
      llm.reply = answer;
      await tester.enterText(find.byType(TextField), 'And in general?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(llm.requests.last.messages.last.text, isNot(contains('The question is about game')));
    });
  });

  group('asking by voice', () {
    String typed(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('words go into the field, after what was typed; sending stays a tap', (
      tester,
    ) async {
      await pumpCoach(tester);
      await tester.enterText(find.byType(TextField), 'Coach,');
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      expect(find.byTooltip('Stop listening'), findsOneWidget);

      speech.hear('why do I lose');
      await tester.pump();
      speech.hear('why do I lose with black');
      await tester.pump();
      expect(typed(tester), 'Coach, why do I lose with black');

      speech.finish(); // a pause ends it
      await tester.pump();
      expect(find.byTooltip('Ask by voice'), findsOneWidget);
      expect(llm.requests, isEmpty, reason: 'nothing is sent by itself');
    });

    testWidgets('tapping the mic again stops listening', (tester) async {
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop listening'));
      await tester.pump();
      expect((speech.stops, speech.isListening), (1, false));
      expect(find.byTooltip('Ask by voice'), findsOneWidget);
    });

    testWidgets('tapping into the field to fix a word stops listening', (tester) async {
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      speech.hear('why do I loose');
      await tester.pump();

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect((speech.stops, speech.isListening), (1, false));
      expect(find.byTooltip('Ask by voice'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'why do I loose',
        reason: 'the words stay, to fix',
      );
    });

    testWidgets('sending while listening stops it', (tester) async {
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      speech.hear('what went wrong');
      await tester.pump();

      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(speech.isListening, isFalse);
      expect(llm.requests.first.messages.last.text, contains('Question: what went wrong'));
    });

    testWidgets('without microphone access, says where to allow it', (tester) async {
      speech.result = SpeechStart.denied;
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      expect(find.textContaining('allow MoveWise to use the microphone'), findsOneWidget);
      expect(find.byTooltip('Ask by voice'), findsOneWidget, reason: 'they may allow it later');
    });

    testWidgets('when nothing is heard, says so instead of stopping quietly', (tester) async {
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      speech.finish(SpeechProblem.notHeard);
      await tester.pump();
      expect(find.text('I didn’t catch that. Tap the mic and try again.'), findsOneWidget);
      expect(find.byTooltip('Ask by voice'), findsOneWidget);
    });

    testWidgets('an error after some words keeps them, without a message', (tester) async {
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      speech.hear('what went wrong');
      speech.finish(SpeechProblem.notHeard);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'what went wrong');
    });

    testWidgets('recognition that fails to start says so; the mic stays', (tester) async {
      speech.result = SpeechStart.failed;
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      expect(find.textContaining('couldn’t start'), findsOneWidget);
      expect(find.byTooltip('Ask by voice'), findsOneWidget);
    });

    testWidgets('without speech recognition, the mic goes away', (tester) async {
      speech.result = SpeechStart.unavailable;
      await pumpCoach(tester);
      await tester.tap(find.byTooltip('Ask by voice'));
      await tester.pump();
      expect(find.text('Voice input isn’t available on this phone.'), findsOneWidget);
      expect(find.byTooltip('Ask by voice'), findsNothing);
    });
  });
}
