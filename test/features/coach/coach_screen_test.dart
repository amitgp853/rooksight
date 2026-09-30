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
import 'package:move_wise/core/storage/chat_repository.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/features/coach/chats_screen.dart';
import 'package:move_wise/features/coach/coach_screen.dart';
import 'package:move_wise/features/coach/domain/coach_tools.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_chat_repository.dart';
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
  late FakeChatRepository chats;
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
    chats = FakeChatRepository();
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
        GoRoute(path: '/coach/chats', builder: (context, state) => const ChatsScreen()),
        GoRoute(
          path: '/coach/chats/:id',
          builder: (context, state) => CoachScreen(chatId: int.parse(state.pathParameters['id']!)),
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
          chatRepositoryProvider.overrideWithValue(chats),
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

  testWidgets('offline: a spaced banner above the composer, and Try again from it', (tester) async {
    llm.failure = const LlmOffline();
    await pumpCoach(tester);
    await tester.tap(find.text('Why do I keep losing?'));
    await tester.pumpAndSettle();
    final banner = find.textContaining('You’re offline');
    expect(banner, findsOneWidget);
    // Not flush against the composer.
    final gap = tester.getTopLeft(find.byType(TextField)).dy - tester.getBottomLeft(banner).dy;
    expect(gap, greaterThanOrEqualTo(18));

    llm.failure = null;
    final retry = find.descendant(
      of: find.ancestor(of: banner, matching: find.byType(Row)).first,
      matching: find.text('Try again'),
    );
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(find.text('You opened lines to your own king.'), findsOneWidget);
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

  group('saved chats', () {
    /// A chat saved earlier: one question and its answer.
    Future<int> savedChat({
      String body = 'Keep your king pawns at home.',
      String? verifiedMove,
    }) async {
      final at = DateTime(2026, 9, 26, 10);
      final chat = await chats.create(
        const NewChat(title: 'Why do I lose?', scopeLabel: 'Your recent games'),
        at,
      );
      await chats.addMessage(
        chat,
        StoredMessage(role: ChatRole.user, at: at, body: 'Why do I lose?'),
      );
      await chats.addMessage(
        chat,
        StoredMessage(
          role: ChatRole.coach,
          at: at,
          body: 'You weaken your king.\n$body',
          payload: {
            'headline': 'You weaken your king.',
            'body': body,
            'steps': [
              {'label': 'Checked your last 20 games'},
            ],
          },
        ),
      );
      if (verifiedMove != null) {
        await chats.updateContext(
          chat,
          verified: {
            'moves': [verifiedMove],
          },
        );
      }
      return chat;
    }

    testWidgets('a new chat is saved when its first question is sent', (tester) async {
      await pumpCoach(tester);
      expect(await chats.watchChats().first, isEmpty, reason: 'nothing saved before sending');

      await tester.tap(find.text('Why do I keep losing?'));
      await tester.pumpAndSettle();

      final saved = (await chats.watchChats().first).single;
      expect(saved.title, 'Why do I keep losing?');
      expect(saved.messageCount, 2);
      expect([for (final m in chats.added) m.role], [ChatRole.user, ChatRole.coach]);
      expect(saved.thumbFen, isNotNull, reason: 'the move card gives it a picture');
    });

    testWidgets('reopening a saved chat reads it back and never calls the AI', (tester) async {
      final chat = await savedChat();
      await pumpCoach(tester, location: '/coach/chats/$chat');

      expect(find.text('Why do I lose?'), findsWidgets); // Header and bubble.
      expect(find.text('You weaken your king.'), findsOneWidget);
      expect(find.text('WORKED THROUGH 1 STEP'), findsOneWidget);
      expect(find.text('Checked your last 20 games'), findsNothing, reason: 'steps start folded');
      expect(find.textContaining('Continue this chat below'), findsNothing);
      expect(find.text('Sat 26 Sep'), findsOneWidget);
      expect(llm.requests, isEmpty);
    });

    testWidgets('continuing sends the conversation, and may name moves from before', (
      tester,
    ) async {
      final chat = await savedChat(verifiedMove: 'Qh4');
      llm = FakeLlm(reply: jsonEncode({'headline': 'Yes.', 'body': 'Qh4 was the threat.'}));
      await pumpCoach(tester, location: '/coach/chats/$chat');

      await tester.enterText(find.byType(TextField), 'Was that the threat?');
      await tester.pump(); // The send button enables on the next frame.
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      final sent = llm.requests.first.messages;
      expect(sent.first.text, 'Why do I lose?');
      expect(sent[1].text, contains('You weaken your king.'));
      expect(find.text('Qh4 was the threat.'), findsOneWidget, reason: 'Qh4 was verified before');
      expect((await chats.chat(chat))!.messageCount, 4);
    });

    testWidgets('a full chat asks for a new one and stops sending', (tester) async {
      final chat = await savedChat(body: 'A long answer. ' * 600);
      await pumpCoach(tester, location: '/coach/chats/$chat');

      expect(find.text('Context memory is full. Please start a new chat.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'One more?');
      await tester.pump();
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_upward)).onPressed,
        isNull,
      );
    });

    testWidgets('the new chat offers the latest chat to pick up', (tester) async {
      final chat = await savedChat();
      await pumpCoach(tester);
      expect(find.text('PICK UP WHERE YOU LEFT OFF'), findsOneWidget);
      await tester.tap(find.text('Why do I lose?'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachScreen), findsOneWidget);
      expect(find.text('You weaken your king.'), findsOneWidget);
      expect(chat, 1);
      expect(llm.requests, isEmpty);
    });

    testWidgets('the list: search, and delete from the options', (tester) async {
      await savedChat();
      await chats.create(
        const NewChat(title: 'Openings', scopeLabel: 'Your recent games'),
        DateTime(2026, 9, 1),
      );
      await pumpCoach(tester, location: '/coach/chats');

      expect(find.text('2 chats · saved on this phone'), findsOneWidget);
      expect(find.text('Why do I lose?'), findsOneWidget);
      expect(find.text('Openings'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'king');
      await tester.pumpAndSettle();
      expect(find.text('Openings'), findsNothing, reason: 'matches the answer text only');
      expect(find.text('Why do I lose?'), findsOneWidget);

      await tester.tap(find.byTooltip('Options for Why do I lose?'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this chat?'), findsOneWidget);
      await tester.tap(find.text('Delete chat'));
      await tester.pumpAndSettle();
      expect(await chats.watchChats().first, hasLength(1));
    });

    testWidgets('no chats yet', (tester) async {
      await pumpCoach(tester, location: '/coach/chats');
      expect(find.text('No chats yet'), findsOneWidget);
      expect(find.text('Ask the AI Coach'), findsOneWidget);
    });
  });
}
