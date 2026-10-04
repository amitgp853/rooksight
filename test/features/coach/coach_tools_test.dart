// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llm_tool/llm_tool.dart';
import 'package:rooksight/core/llm/gemini_client.dart';
import 'package:rooksight/core/llm/llm_client.dart';
import 'package:rooksight/features/coach/domain/coach_tools.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

/// The arguments' problems, as the model would read them.
Matcher _rejects(String problem) =>
    throwsA(isA<ToolArgumentException>().having((e) => e.toString(), 'message', contains(problem)));

void main() {
  final coach = CoachTools(
    games: FakeGameRepository(),
    analyses: FakeAnalysisRepository(),
    engine: FakeEngine(),
    depth: 16,
  );
  ToolDefinition<ToolOutcome> tool(String name) => coach.llmTools.firstWhere((t) => t.name == name);

  group('declarations', () {
    test('CoachTools names match the generated tools', () {
      // A rename on one side only would leave the agent unable to run a tool.
      expect(coach.llmTools.map((tool) => tool.name), [
        CoachTools.analyzePosition,
        CoachTools.getGameMistakes,
        CoachTools.getMyStats,
        CoachTools.evaluateMove,
        CoachTools.getPosition,
      ]);
    });

    test('Gemini gets the same tools as before the generator', () {
      // The schemas that were written by hand: generating them must not
      // change a byte of the request.
      final body = GeminiClient.requestBody(
        LlmRequest(messages: const [LlmMessage.user('?')], tools: coach.declarations),
      );
      final declarations =
          ((body['tools']! as List).single as Map)['functionDeclarations'] as List<Object?>;
      expect(declarations.take(3), [
        {
          'name': 'analyze_position',
          'description':
              'Stockfish\'s evaluation and best line for a chess position. Use it to '
              'check a move or to look deeper at a position from a game.',
          'parameters': {
            'type': 'object',
            'properties': {
              'fen': {'type': 'string', 'description': 'The position in FEN.'},
            },
            'required': ['fen'],
          },
        },
        {
          'name': 'get_game_mistakes',
          'description':
              'The player\'s mistakes in one reviewed game: each move, the evaluation '
              'before and after, Stockfish\'s best move and line, what the move '
              'allowed, and the position before it (FEN). "best_line_material" and '
              '"allowed_material" are the mover\'s material change in pawns at the '
              'end of each line, left out when nothing changes.',
          'parameters': {
            'type': 'object',
            'properties': {
              'game_id': {'type': 'integer', 'description': 'A game id from the list of games.'},
            },
            'required': ['game_id'],
          },
        },
        {
          'name': 'get_my_stats',
          'description':
              'The player\'s results across their recent games: by opening and colour, '
              'mistakes and blunders per game and by game phase, losses from winning '
              'positions, and their three costliest moves.',
        },
      ]);
    });

    test('get_position\'s side is one of two values, as Gemini gets it', () {
      final body = GeminiClient.requestBody(
        LlmRequest(messages: const [LlmMessage.user('?')], tools: coach.declarations),
      );
      final declarations =
          ((body['tools']! as List).single as Map)['functionDeclarations'] as List<Object?>;
      final getPosition = declarations.last! as Map<String, Object?>;
      expect(getPosition['name'], 'get_position');
      expect(getPosition['parameters'], {
        'type': 'object',
        'properties': {
          'game_id': {'type': 'integer', 'description': 'A game id from the list of games.'},
          'move_number': {
            'type': 'integer',
            'description': 'The move number, as on a score sheet: 14 for "14. Nf3" or "14...Nf6".',
          },
          'side': {
            'type': 'string',
            'enum': ['white', 'black'],
            'description': 'Which side made the move.',
          },
        },
        'required': ['game_id', 'move_number', 'side'],
      });
    });

    test('the names CoachTools uses are the generated ones', () {
      expect(coach.llmTools.map((tool) => tool.name), [
        CoachTools.analyzePosition,
        CoachTools.getGameMistakes,
        CoachTools.getMyStats,
        CoachTools.evaluateMove,
        CoachTools.getPosition,
      ]);
    });

    test('none of them needs confirming: they only read', () {
      expect(coach.llmTools.where((tool) => tool.requiresConfirmation), isEmpty);
    });

    test('the tools the model sees match the snapshot', () {
      // The descriptions and parameters are the prompt Gemini reads, so a
      // change to them should be a reviewed diff. If a change is intended,
      // delete the JSON file and run the tests again to write a new one.
      final file = File('test/features/coach/coach_tools_schemas.json');
      final snapshot = toolSchemaSnapshot(coach.llmTools);
      if (!file.existsSync()) file.writeAsStringSync(snapshot);
      expect(snapshot, file.readAsStringSync());
    });
  });

  group('analyze_position', () {
    test('a missing FEN is reported', () {
      expect(tool('analyze_position').call({}), _rejects('fen is required'));
    });

    test('a FEN that isn\'t a string is reported', () {
      expect(
        tool('analyze_position').call({'fen': 42}),
        _rejects('fen must be a string, got integer'),
      );
    });

    test('unknown arguments are reported', () {
      expect(
        tool('analyze_position').call({'fen': _fen, 'depth': 30}),
        _rejects('depth is not a known argument'),
      );
    });
  });

  group('get_game_mistakes', () {
    test('a whole number sent as 7.0 is accepted', () async {
      // There's no game 7, so the tool ran and says so.
      final outcome = await tool('get_game_mistakes').call({'game_id': 7.0});
      expect(outcome.result, contains('error'));
    });

    test('a missing id is reported', () {
      expect(tool('get_game_mistakes').call({}), _rejects('game_id is required'));
    });

    test('a null id is reported as missing', () {
      expect(tool('get_game_mistakes').call({'game_id': null}), _rejects('game_id is required'));
    });

    test('an id sent as text is reported', () {
      expect(
        tool('get_game_mistakes').call({'game_id': '7'}),
        _rejects('game_id must be an integer, got string'),
      );
    });

    test('a fractional id is reported', () {
      expect(
        tool('get_game_mistakes').call({'game_id': 7.5}),
        _rejects('game_id must be an integer, got number'),
      );
    });

    test('every problem is reported at once, with the tool\'s name', () {
      expect(
        tool('get_game_mistakes').call({'id': 7}),
        _rejects(
          'Invalid arguments for "get_game_mistakes": game_id is required; '
          'id is not a known argument',
        ),
      );
    });
  });

  group('get_my_stats', () {
    test('no arguments: the stats', () async {
      expect(await tool('get_my_stats').call({}), isA<ToolOutcome>());
    });

    test('any argument is reported', () {
      expect(tool('get_my_stats').call({'limit': 20}), _rejects('limit is not a known argument'));
    });
  });

  group('evaluate_move', () {
    test('both are required', () {
      expect(tool('evaluate_move').call({'move': 'Nf6'}), _rejects('fen is required'));
      expect(tool('evaluate_move').call({'fen': _fen}), _rejects('move is required'));
    });

    test('a move that isn\'t text is reported', () {
      expect(
        tool('evaluate_move').call({'fen': _fen, 'move': 5}),
        _rejects('move must be a string, got integer'),
      );
    });
  });

  group('get_position', () {
    test('a side other than white or black is reported with both choices', () {
      expect(
        tool('get_position').call({'game_id': 3, 'move_number': 14, 'side': 'w'}),
        _rejects('side must be one of "white", "black", got "w"'),
      );
    });

    test('a move number sent as text is reported', () {
      expect(
        tool('get_position').call({'game_id': 3, 'move_number': '14', 'side': 'white'}),
        _rejects('move_number must be an integer, got string'),
      );
    });

    test('every missing argument is reported at once', () {
      expect(
        tool('get_position').call({'game_id': 3}),
        _rejects('move_number is required; side is required'),
      );
    });
  });
}
