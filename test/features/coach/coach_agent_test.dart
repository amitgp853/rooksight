import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/llm/llm_client.dart';
import 'package:rooksight/engine/uci.dart';
import 'package:rooksight/features/coach/domain/coach_agent.dart';
import 'package:rooksight/features/coach/domain/coach_tools.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';
import '../../support/fake_llm.dart';
import 'coach_fixtures.dart';

void main() {
  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;
  late FakeEngine engine;
  late CoachTools tools;
  late int mateId;
  late int sicilianId;

  setUp(() async {
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
    // Stockfish agrees with the stored analysis: 2. d4 before g4.
    engine = FakeEngine(
      reply: (fen) => [
        EngineLine(
          rank: 1,
          depth: 16,
          score: const EngineScore.centipawns(-55),
          pv: fen == beforeG4 ? const ['d2d4', 'g8f6'] : [FakeEngine.firstLegalMove(fen)],
        ),
      ],
    );
    mateId = await games.save(foolsMate);
    sicilianId = await games.save(sicilianWin);
    analyses.analyses[mateId] = foolsMateAnalysis;
    tools = CoachTools(games: games, analyses: analyses, engine: engine, depth: 16);
  });

  Future<ToolOutcome> run(String name, [Map<String, Object?> args = const {}]) => tools.run(
    LlmToolCall(name: name, args: args),
    onStart: (_) {},
  );

  String answer({String headline = 'h', required String body, String? tryThis, Object? move}) =>
      jsonEncode({'headline': headline, 'body': body, 'try_this': ?tryThis, 'move': ?move});

  group('tools', () {
    test('get_game_mistakes: Stockfish\'s facts per mistake, compactly', () async {
      final outcome = await run(CoachTools.getGameMistakes, {'game_id': mateId});
      final result = outcome.result;
      expect(result['vs'], 'Stockfish 1600');
      expect(result['result'], 'loss');
      expect(result['blunders'], 1);
      final moments = result['moments']! as List<Object?>;
      final g4 = moments.cast<Map<String, Object?>>().firstWhere((m) => m['move_id'] == 2);
      expect(g4['move'], '2. g4');
      expect(g4['best_move'], '2. d4');
      expect(g4['what_the_move_allowed'], 'Qh4#');
      expect(g4['fen_before'], beforeG4);

      expect(outcome.step.label, 'Your game vs Stockfish 1600');
      expect(outcome.step.detail, startsWith('1 blunder · 0 mistakes'));
      expect(tools.moves, containsAll(['g4', 'd4', 'Qh4']));
      expect(tools.gameMoves[(mateId, 2)]!.best, 'd4');
    });

    test('get_game_mistakes on a game that isn\'t reviewed says so', () async {
      final outcome = await run(CoachTools.getGameMistakes, {'game_id': sicilianId});
      expect(outcome.result['reviewed'], false);
      expect(outcome.step.detail, 'Not reviewed yet');
    });

    test('get_game_mistakes accepts ids as the model sends them', () async {
      expect((await run(CoachTools.getGameMistakes, {'game_id': 1.0})).result['game_id'], 1);
      expect((await run(CoachTools.getGameMistakes, {'game_id': 99})).result['error'], isNotNull);
    });

    test('analyze_position: a move from a game is named and verified', () async {
      await run(CoachTools.getGameMistakes, {'game_id': mateId});
      final labels = <String>[];
      final outcome = await tools.run(
        const LlmToolCall(name: CoachTools.analyzePosition, args: {'fen': beforeG4}),
        onStart: labels.add,
      );
      expect(labels, ['Asking Stockfish about move 2…']);
      expect(outcome.step.label, 'Verified best move: d4');
      expect(outcome.step.detail, 'd4 · −0.6 · depth 16');
      expect(outcome.result, {
        'side_to_move': 'white',
        'eval': -0.55,
        'best_move': 'd4',
        'line': 'd4 Nf6',
        'depth': 16,
      });
      expect(engine.searches.single.limits.depth, 16);
    });

    test('analyze_position rejects a broken FEN without asking Stockfish', () async {
      final outcome = await run(CoachTools.analyzePosition, {'fen': 'not a position'});
      expect(outcome.result['error'], isNotNull);
      expect(engine.searches, isEmpty);
    });

    test('get_my_stats: results, openings and the costliest moves', () async {
      final result = (await run(CoachTools.getMyStats)).result;
      expect(result['games'], 2);
      expect(result['reviewed_games'], 1);
      final costliest = (result['costliest_moves']! as List).single as Map<String, Object?>;
      expect(costliest, containsPair('move', '2. g4'));
      expect(costliest, containsPair('game_id', mateId));
      expect(tools.gameMoves.keys, contains((mateId, 2)));
    });

    test('a failing engine is an error for the model, not a crash', () async {
      engine.fail = true;
      final outcome = await run(CoachTools.analyzePosition, {'fen': beforeG4});
      expect(outcome.result['error'], isNotNull);
      expect(outcome.step.done, isTrue);
    });

    test('the context lists recent games and the move asked about', () async {
      tools.focus = CoachFocus(gameId: mateId, index: 2, label: '2. g4');
      final context = await tools.context();
      expect(context, contains('\n$mateId | '));
      expect(context, contains('| Stockfish 1600 | white | loss | yes'));
      expect(context, contains('move_id 2 (2. g4)'));
    });

    test('an attached game is named in the question, reviewed or not', () async {
      tools.focus = CoachFocus(gameId: mateId, label: 'vs Stockfish 1600');
      expect(
        await tools.context(),
        contains('The question is about game $mateId: vs Stockfish 1600'),
      );

      tools.focus = CoachFocus(gameId: sicilianId, label: 'vs magnus_fan');
      expect(await tools.context(), contains('not reviewed yet'));
    });
  });

  group('agent loop', () {
    test('tool, result, answer: two model calls, steps as they happen', () async {
      final llm = FakeLlm(
        turns: [
          toolCall(CoachTools.getGameMistakes, {'game_id': mateId}),
        ],
        reply: answer(
          headline: 'You opened lines to your own king.',
          body: '2. g4 allowed Qh4# at once. 2. d4 kept it closed.',
          tryThis: 'Keep the pawns in front of your king at home early on.',
          move: {'game_id': mateId, 'move_id': 2},
        ),
      );
      final steps = <int, AgentStep>{};
      final result = await CoachAgent(
        llm,
        tools,
      ).ask('What went wrong?', onStep: (i, step) => steps[i] = step);

      expect(llm.requests, hasLength(2));
      expect(llm.requests.first.tools, CoachTools.declarations);
      expect(llm.requests.first.messages.last.text, contains('Question: What went wrong?'));
      final toolResult = llm.requests.last.messages.last.toolResults.single;
      expect(toolResult.call.name, CoachTools.getGameMistakes);
      expect(toolResult.result['game_id'], mateId);

      expect(steps.values.map((s) => s.label), [
        'Your game vs Stockfish 1600',
        'Writing your answer',
      ]);
      expect(steps.values.every((s) => s.done), isTrue);

      expect(result.headline, 'You opened lines to your own king.');
      expect(result.body, '2. g4 allowed Qh4# at once. 2. d4 kept it closed.');
      expect(result.move?.label, '2. g4');
      expect((result.llmCalls, result.toolCalls), (2, 1));
    });

    test('at most 5 tool calls; then the model must answer', () async {
      final llm = FakeLlm(
        turns: [for (var i = 0; i < 5; i++) toolCall(CoachTools.getMyStats)],
        reply: answer(body: 'Enough.'),
      );
      final result = await CoachAgent(llm, tools).ask('?', onStep: (_, _) {});

      expect(llm.requests, hasLength(6));
      expect(llm.requests.take(5).map((r) => r.toolMode), everyElement(LlmToolMode.auto));
      expect(llm.requests.last.toolMode, LlmToolMode.none);
      expect((result.llmCalls, result.toolCalls), (6, 5));
    });

    test('a question about one game starts with its mistakes: no tool round trip', () async {
      tools.focus = CoachFocus(gameId: mateId, index: 2, label: '2. g4');
      final llm = FakeLlm(reply: answer(body: '2. g4 allowed Qh4#. 2. d4 kept it closed.'));
      final steps = <int, AgentStep>{};
      final result = await CoachAgent(llm, tools).ask('Why?', onStep: (i, s) => steps[i] = s);

      expect(llm.requests, hasLength(1));
      final prompt = llm.requests.single.messages.last.text;
      expect(prompt, contains('Already looked up, get_game_mistakes($mateId)'));
      expect(prompt, contains('"what_the_move_allowed":"Qh4#"'));
      expect(prompt, endsWith('Question: Why?'));
      expect(steps[0]!.label, 'Your game vs Stockfish 1600');
      expect(result.body, '2. g4 allowed Qh4#. 2. d4 kept it closed.');
      expect((result.llmCalls, result.toolCalls), (1, 1));
    });

    test('adds up the tokens of every call', () async {
      final llm = FakeLlm(
        turns: [
          LlmReply(
            message: toolCall(CoachTools.getMyStats).message,
            usage: const LlmUsage(input: 1000, cached: 200, output: 20, thinking: 100),
          ),
        ],
        reply: answer(body: 'Done.'),
        usage: const LlmUsage(input: 1500, cached: 900, output: 80, thinking: 300),
      );
      final result = await CoachAgent(llm, tools).ask('?', onStep: (_, _) {});

      expect(result.usage, const LlmUsage(input: 2500, cached: 1100, output: 100, thinking: 400));
    });

    test('calls beyond the limit in one turn don\'t run but still get a result', () async {
      final many = LlmReply(
        message: LlmMessage.model(
          '',
          toolCalls: [
            for (var i = 0; i < 7; i++)
              const LlmToolCall(name: CoachTools.analyzePosition, args: {'fen': beforeG4}),
          ],
        ),
      );
      final llm = FakeLlm(
        turns: [many],
        reply: answer(body: 'Done.'),
      );
      await CoachAgent(llm, tools).ask('?', onStep: (_, _) {});

      expect(engine.searches, hasLength(CoachAgent.maxToolCalls));
      final results = llm.requests.last.messages.last.toolResults;
      expect(results, hasLength(7));
      expect(results.last.result['error'], contains('limit'));
      expect(llm.requests.last.toolMode, LlmToolMode.none);
    });

    test('a model that still calls tools after the limit fails cleanly', () async {
      final llm = FakeLlm(turns: [for (var i = 0; i < 6; i++) toolCall(CoachTools.getMyStats)]);
      expect(CoachAgent(llm, tools).ask('?', onStep: (_, _) {}), throwsA(isA<LlmUnavailable>()));
    });

    test('an unknown tool goes back as an error and the loop goes on', () async {
      final llm = FakeLlm(
        turns: [toolCall('play_for_me')],
        reply: answer(body: 'Sorry.'),
      );
      final result = await CoachAgent(llm, tools).ask('?', onStep: (_, _) {});
      expect(llm.requests.last.messages.last.toolResults.single.result['error'], isNotNull);
      expect(result.body, 'Sorry.');
    });

    test('a question that isn\'t about chess gets the fixed reply', () async {
      final llm = FakeLlm(
        reply: jsonEncode({
          'headline': 'Here is a poem',
          'body': 'Roses are red…',
          'off_topic': true,
        }),
      );
      final result = await CoachAgent(llm, tools).ask('Write me a poem', onStep: (_, _) {});

      expect(result.offTopic, isTrue);
      expect(result.headline, 'I can only help with chess');
      expect(result.body, isNot(contains('Roses')), reason: 'the model\'s text is dropped');
      expect((result.tryThis, result.move), (null, null));
    });

    test('chess answers are not flagged', () async {
      final llm = FakeLlm(reply: answer(body: 'Develop your pieces first.'));
      final result = await CoachAgent(llm, tools).ask('How do I open?', onStep: (_, _) {});
      expect(result.offTopic, isFalse);
      expect(result.body, 'Develop your pieces first.');
    });

    test('the scope rule goes to the model', () async {
      final llm = FakeLlm(reply: answer(body: 'Yes.'));
      await CoachAgent(llm, tools).ask('?', onStep: (_, _) {});
      expect(llm.requests.single.system, contains('you only help with chess'));
      final properties = llm.requests.single.jsonSchema!['properties']! as Map<String, Object?>;
      expect(properties, contains('off_topic'));
    });

    test('AI failures reach the caller', () async {
      final llm = FakeLlm(failure: const LlmRateLimited());
      expect(CoachAgent(llm, tools).ask('?', onStep: (_, _) {}), throwsA(isA<LlmRateLimited>()));
    });

    test('earlier questions go along for follow-ups', () async {
      final llm = FakeLlm(reply: answer(body: 'Yes.'));
      await CoachAgent(llm, tools).ask(
        'And then?',
        history: const [LlmMessage.user('First?'), LlmMessage.model('First answer.')],
        onStep: (_, _) {},
      );
      expect(llm.requests.single.messages.map((m) => m.text).take(2), ['First?', 'First answer.']);
    });
  });

  group('move check', () {
    setUp(() => run(CoachTools.getGameMistakes, {'game_id': 1}));

    test('sentences with moves no tool reported are dropped', () {
      final result = CoachAgent.checked(
        answer(
          headline: 'Nf3 would have saved you.',
          body: '2. g4 allowed Qh4#. Bb5 would pin the knight. Keep your king safe.',
          tryThis: 'Play Nc3 first.',
        ),
        tools,
      );
      expect(result.headline, isNull);
      expect(result.body, '2. g4 allowed Qh4#. Keep your king safe.');
      expect(result.tryThis, isNull);
    });

    test('the move card must be a move the tools described', () {
      final made = CoachAgent.checked(answer(body: 'x', move: {'game_id': 1, 'move_id': 3}), tools);
      expect(made.move, isNull);
      final real = CoachAgent.checked(answer(body: 'x', move: {'game_id': 1, 'move_id': 2}), tools);
      expect(real.move?.label, '2. g4');
    });

    test('an answer with nothing checkable left says so', () {
      final result = CoachAgent.checked(answer(body: 'Play Bb5.'), tools);
      expect(result.body, startsWith('I couldn’t put together an answer'));
    });

    test('a reply that isn\'t JSON is kept as checked plain text', () {
      final result = CoachAgent.checked('Your g4 allowed Qh4#. Try Bb5.', tools);
      expect(result.body, 'Your g4 allowed Qh4#.');
      expect(result.headline, isNull);
    });
  });
}
