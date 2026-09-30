import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:move_wise/core/llm/gemini_client.dart';
import 'package:move_wise/core/llm/llm_client.dart';

const request = LlmRequest(
  system: 'Be brief.',
  messages: [LlmMessage.user('Hello')],
  jsonSchema: {'type': 'object'},
);

http.Response reply(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, Object?> answer(List<Map<String, Object?>> parts) => {
  'candidates': [
    {
      'content': {'role': 'model', 'parts': parts},
    },
  ],
};

void main() {
  test('posts to the model with the key in a header, never the URL', () async {
    late http.Request sent;
    final client = GeminiClient(
      apiKey: 'secret',
      model: 'gemini-test',
      client: MockClient((r) async {
        sent = r;
        return reply(
          answer([
            {'text': '{"ok":true}'},
          ]),
        );
      }),
    );

    expect(await client.generate(request), '{"ok":true}');
    expect(
      sent.url.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent',
    );
    expect(sent.headers['x-goog-api-key'], 'secret');
    expect(sent.url.query, isNot(contains('secret')));

    final body = jsonDecode(sent.body) as Map<String, Object?>;
    expect(body['systemInstruction'], {
      'parts': [
        {'text': 'Be brief.'},
      ],
    });
    expect(body['contents'], [
      {
        'role': 'user',
        'parts': [
          {'text': 'Hello'},
        ],
      },
    ]);
    final config = body['generationConfig']! as Map<String, Object?>;
    expect(config['responseMimeType'], 'application/json');
    expect(config['responseJsonSchema'], {'type': 'object'});
  });

  test('joins text parts and skips thoughts', () async {
    final client = GeminiClient(
      apiKey: 'k',
      model: 'm',
      client: MockClient(
        (_) async => reply(
          answer([
            {'text': 'thinking…', 'thought': true},
            {'text': '{"a":'},
            {'text': '1}'},
          ]),
        ),
      ),
    );
    expect(await client.generate(request), '{"a":1}');
  });

  group('failures', () {
    Future<void> expectFailure(http.Response response, Matcher matcher) {
      final client = GeminiClient(
        apiKey: 'k',
        model: 'm',
        client: MockClient((_) async => response),
        wait: (_) async {}, // Retries don't really sleep in tests.
      );
      return expectLater(client.generate(request), throwsA(matcher));
    }

    test('no key', () {
      final client = GeminiClient(
        apiKey: '',
        model: 'm',
        client: MockClient((_) async => reply({})),
      );
      expect(client.generate(request), throwsA(isA<LlmMissingKey>()));
    });

    test('a rejected key', () async {
      await expectFailure(
        reply({
          'error': {'status': 'INVALID_ARGUMENT', 'message': 'API key not valid.'},
        }, 400),
        isA<LlmInvalidKey>(),
      );
      await expectFailure(reply({}, 403), isA<LlmInvalidKey>());
    });

    test('the free-tier limit', () => expectFailure(reply({}, 429), isA<LlmRateLimited>()));

    test('a server error', () => expectFailure(reply({}, 503), isA<LlmUnavailable>()));

    test(
      'a blocked prompt',
      () => expectFailure(
        reply({
          'promptFeedback': {'blockReason': 'SAFETY'},
        }),
        isA<LlmUnavailable>(),
      ),
    );

    test(
      'an empty answer',
      () => expectFailure(reply({'candidates': <Object>[]}), isA<LlmUnavailable>()),
    );

    test('no connection', () {
      final client = GeminiClient(
        apiKey: 'k',
        model: 'm',
        client: MockClient((_) async => throw http.ClientException('offline')),
        wait: (_) async {},
      );
      expect(client.generate(request), throwsA(isA<LlmOffline>()));
    });
  });

  group('retries', () {
    /// A client whose server answers with [responses] in turn, recording
    /// how many requests it got and each wait between them.
    (GeminiClient, List<Duration>, int Function()) scripted(List<http.Response> responses) {
      final waits = <Duration>[];
      var calls = 0;
      final client = GeminiClient(
        apiKey: 'k',
        model: 'm',
        client: MockClient((_) async => responses[calls++]),
        wait: (d) async => waits.add(d),
        random: Random(1),
      );
      return (client, waits, () => calls);
    }

    final ok = reply(
      answer([
        {'text': 'fine'},
      ]),
    );

    test('a server error is retried with backoff', () async {
      final (client, waits, calls) = scripted([reply({}, 503), reply({}, 500), ok]);
      expect(await client.generate(request), 'fine');
      expect(calls(), 3);
      expect(waits, hasLength(2));
      // Equal jitter: attempt 1 waits 1–2s, attempt 2 waits 2–4s.
      expect(waits[0].inMilliseconds, inInclusiveRange(1000, 2000));
      expect(waits[1].inMilliseconds, inInclusiveRange(2000, 4000));
    });

    test('gives up after 4 attempts', () async {
      final (client, _, calls) = scripted([for (var i = 0; i < 4; i++) reply({}, 503)]);
      await expectLater(client.generate(request), throwsA(isA<LlmUnavailable>()));
      expect(calls(), GeminiClient.maxAttempts);
    });

    test('a short rate limit waits as long as Gemini asks, plus a little jitter', () async {
      final limited = reply({
        'error': {
          'code': 429,
          'status': 'RESOURCE_EXHAUSTED',
          'details': [
            {'@type': 'type.googleapis.com/google.rpc.RetryInfo', 'retryDelay': '7s'},
          ],
        },
      }, 429);
      final (client, waits, _) = scripted([limited, ok]);
      expect(await client.generate(request), 'fine');
      expect(waits.single.inMilliseconds, inInclusiveRange(7000, 7500));
    });

    test('a long rate limit (daily quota) fails at once', () async {
      final limited = reply({
        'error': {
          'details': [
            {'@type': 'type.googleapis.com/google.rpc.RetryInfo', 'retryDelay': '3600s'},
          ],
        },
      }, 429);
      final (client, waits, calls) = scripted([limited, ok]);
      await expectLater(client.generate(request), throwsA(isA<LlmRateLimited>()));
      expect(calls(), 1);
      expect(waits, isEmpty);
    });

    test('a dropped connection is retried', () async {
      var calls = 0;
      final client = GeminiClient(
        apiKey: 'k',
        model: 'm',
        client: MockClient((_) async {
          if (calls++ == 0) throw http.ClientException('reset');
          return ok;
        }),
        wait: (_) async {},
      );
      expect(await client.generate(request), 'fine');
    });

    test('no connection at all fails after one quick retry', () async {
      var calls = 0;
      final waits = <Duration>[];
      final client = GeminiClient(
        apiKey: 'k',
        model: 'm',
        client: MockClient((_) async {
          calls++;
          throw http.ClientException('Failed host lookup');
        }),
        wait: (d) async => waits.add(d),
      );
      await expectLater(client.generate(request), throwsA(isA<LlmOffline>()));
      expect(calls, 2);
      expect(waits, [const Duration(milliseconds: 500)]);
    });

    test('a timeout fails at once, without more waiting', () async {
      var calls = 0;
      final client = GeminiClient(
        apiKey: 'k',
        model: 'm',
        client: MockClient((_) async {
          calls++;
          throw TimeoutException('slow');
        }),
        wait: (_) async {},
      );
      await expectLater(client.generate(request), throwsA(isA<LlmOffline>()));
      expect(calls, 1);
    });

    test('a rejected key is never retried', () async {
      final (client, _, calls) = scripted([reply({}, 403), ok]);
      await expectLater(client.generate(request), throwsA(isA<LlmInvalidKey>()));
      expect(calls(), 1);
    });

    test('reads retryDelay, including fractions', () {
      expect(GeminiClient.retryDelay('{"retryDelay": "1.5s"}'), const Duration(milliseconds: 1500));
      expect(GeminiClient.retryDelay('{}'), isNull);
    });

    test('an overloaded model hands over to the fallback', () async {
      final asked = <String>[];
      final client = GeminiClient(
        apiKey: 'k',
        model: 'big',
        fallbackModels: ['small'],
        wait: (_) async {},
        client: MockClient((r) async {
          asked.add(r.url.pathSegments.last);
          return r.url.path.contains('big') ? reply({}, 503) : ok;
        }),
      );
      expect(await client.generate(request), 'fine');
      expect(asked, [
        for (var i = 0; i < GeminiClient.maxAttempts; i++) 'big:generateContent',
        'small:generateContent',
      ]);
      expect(client.model, 'small', reason: 'stored with what it wrote');
    });

    test('a used-up quota moves to the fallback, which has its own', () async {
      final asked = <String>[];
      final client = GeminiClient(
        apiKey: 'k',
        model: 'big',
        fallbackModels: ['small'],
        wait: (_) async {},
        client: MockClient((r) async {
          asked.add(r.url.pathSegments.last);
          return r.url.path.contains('big')
              ? http.Response('{"error": {"details": [{"retryDelay": "3600s"}]}}', 429)
              : ok;
        }),
      );
      expect(await client.generate(request), 'fine');
      expect(asked, ['big:generateContent', 'small:generateContent']);
    });

    test('a rejected key does not try the fallback', () async {
      var calls = 0;
      final client = GeminiClient(
        apiKey: 'k',
        model: 'big',
        fallbackModels: ['small'],
        wait: (_) async {},
        client: MockClient((_) async {
          calls++;
          return reply({}, 403);
        }),
      );
      await expectLater(client.generate(request), throwsA(isA<LlmInvalidKey>()));
      expect(calls, 1);
    });

    test('only the primary model gets the thinking level', () async {
      final thinking = <String, Object?>{};
      final client = GeminiClient(
        apiKey: 'k',
        model: 'big',
        fallbackModels: ['small'],
        thinkingLevel: 'low',
        wait: (_) async {},
        client: MockClient((r) async {
          final config = (jsonDecode(r.body) as Map)['generationConfig'] as Map;
          final model = r.url.pathSegments.last.split(':').first;
          thinking[model] = config['thinkingConfig'];
          return model == 'big' ? reply({}, 503) : ok;
        }),
      );
      expect(await client.generate(request), 'fine');
      expect(thinking, {
        'big': {'thinkingLevel': 'low'},
        'small': null,
      });
    });
  });

  group('usage', () {
    test('the tokens a reply used are read from its metadata', () {
      final parsed = GeminiClient.parseReply(
        jsonEncode({
          ...answer([
            {'text': 'Hi'},
          ]),
          'usageMetadata': {
            'promptTokenCount': 1200,
            'cachedContentTokenCount': 800,
            'candidatesTokenCount': 90,
            'thoughtsTokenCount': 300,
            'totalTokenCount': 1590,
          },
        }),
      );
      final usage = parsed.usage!;
      expect(usage.input, 1200);
      expect(usage.cached, 800);
      expect(usage.output, 90);
      expect(usage.thinking, 300);
    });

    test('counts left out are zero, and no metadata is no usage', () {
      final lean = GeminiClient.parseReply(
        jsonEncode({
          ...answer([
            {'text': 'Hi'},
          ]),
          'usageMetadata': {'promptTokenCount': 20, 'candidatesTokenCount': 5},
        }),
      );
      expect(lean.usage!.cached, 0);
      expect(lean.usage!.thinking, 0);

      final bare = GeminiClient.parseReply(
        jsonEncode(
          answer([
            {'text': 'Hi'},
          ]),
        ),
      );
      expect(bare.usage, isNull);
    });
  });

  group('tool calling', () {
    const tool = LlmTool(
      name: 'analyze_position',
      description: 'Stockfish on a position.',
      parameters: {
        'type': 'object',
        'properties': {
          'fen': {'type': 'string'},
        },
      },
    );

    test('tools are declared, with the calling mode', () {
      final body = GeminiClient.requestBody(
        const LlmRequest(
          messages: [LlmMessage.user('Hi')],
          tools: [
            tool,
            LlmTool(name: 'get_my_stats', description: 'Stats.'),
          ],
          toolMode: LlmToolMode.none,
        ),
      );
      final declarations =
          ((body['tools']! as List).single as Map)['functionDeclarations'] as List<Object?>;
      expect(declarations, [
        {
          'name': 'analyze_position',
          'description': 'Stockfish on a position.',
          'parameters': tool.parameters,
        },
        {'name': 'get_my_stats', 'description': 'Stats.'},
      ]);
      expect(body['toolConfig'], {
        'functionCallingConfig': {'mode': 'NONE'},
      });
    });

    test('images go before the text, base64-encoded', () {
      final body = GeminiClient.requestBody(
        LlmRequest(
          messages: [
            LlmMessage.user(
              'Read this board',
              images: [
                LlmImage(Uint8List.fromList([1, 2, 3])),
              ],
            ),
          ],
        ),
      );
      final parts = ((body['contents']! as List).single as Map)['parts'] as List<Object?>;
      expect(parts, [
        {
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': base64Encode([1, 2, 3]),
          },
        },
        {'text': 'Read this board'},
      ]);
    });

    test('no tools, no tool config', () {
      final body = GeminiClient.requestBody(request);
      expect(body.containsKey('tools'), isFalse);
      expect(body.containsKey('toolConfig'), isFalse);
    });

    test('a reply with tool calls, skipping thoughts', () {
      final parsed = GeminiClient.parseReply(
        jsonEncode(
          answer([
            {'text': 'Let me check.', 'thought': true},
            {
              'functionCall': {
                'name': 'get_game_mistakes',
                'args': {'game_id': 5},
                'id': 'call-1',
              },
              'thoughtSignature': 'sig',
            },
          ]),
        ),
      );
      expect(parsed.text, isEmpty);
      final call = parsed.toolCalls.single;
      expect(call.name, 'get_game_mistakes');
      expect(call.args, {'game_id': 5});
      expect(call.id, 'call-1');
    });

    test('the model\'s turn goes back unchanged, with its signature, and results follow', () {
      final turn = GeminiClient.parseReply(
        jsonEncode(
          answer([
            {
              'functionCall': {'name': 'get_my_stats', 'args': <String, Object?>{}, 'id': 'c1'},
              'thoughtSignature': 'sig',
            },
          ]),
        ),
      );
      final body = GeminiClient.requestBody(
        LlmRequest(
          messages: [
            const LlmMessage.user('How am I doing?'),
            turn.message,
            LlmMessage.toolResults([
              LlmToolResult(call: turn.toolCalls.single, result: const {'games': 3}),
            ]),
          ],
          tools: const [tool],
        ),
      );
      final contents = body['contents']! as List<Object?>;
      expect(contents[1], {
        'role': 'model',
        'parts': [
          {
            'functionCall': {'name': 'get_my_stats', 'args': <String, Object?>{}, 'id': 'c1'},
            'thoughtSignature': 'sig',
          },
        ],
      });
      expect(contents[2], {
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': 'get_my_stats',
              'id': 'c1',
              'response': {'games': 3},
            },
          },
        ],
      });
    });

    test('a reply with neither text nor tool calls is unusable', () {
      expect(() => GeminiClient.parseReply(jsonEncode(answer([]))), throwsA(isA<LlmUnavailable>()));
    });
  });
}
