// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:llm_tool/llm_tool.dart' show withoutAdditionalProperties;

import '../config/api_keys.dart';
import '../config/remote_config.dart';
import 'gemini_key.dart';
import 'llm_client.dart';

/// Gemini over its REST API (`generateContent`), using the user's own key.
///
/// Brief failures (server errors, timeouts, dropped connections, short rate
/// limits) are retried with exponential backoff and jitter, up to
/// [maxAttempts] tries. If the model stays overloaded or its free quota is
/// used up (a rate limit that asks for a long wait), the request moves to the
/// [fallbackModels] in turn. A rejected key fails at once. A
/// [LlmRequest.light] request starts on [lightModel] instead.
///
/// Each reply's token usage is logged, to see what a review or a coach
/// question really costs.
class GeminiClient implements LlmClient {
  GeminiClient({
    required String apiKey,
    required this.model,
    this.fallbackModels = const [],
    this.thinkingLevel,
    this.lightModel,
    http.Client? client,
    Future<void> Function(Duration)? wait,
    Random? random,
  }) : _apiKey = apiKey,
       _primary = model,
       _client = client ?? http.Client(),
       _wait = wait ?? Future<void>.delayed,
       _random = random ?? Random();

  final String _apiKey;
  final http.Client _client;
  final Future<void> Function(Duration) _wait;
  final Random _random;

  final String _primary;

  /// Tried in order when the models before them stay overloaded.
  final List<String> fallbackModels;

  /// The primary model's thinking level (e.g. `low`); null or empty for its
  /// default. [fallbackModels] always use their own default.
  final String? thinkingLevel;

  /// Tried first for [LlmRequest.light] requests (e.g. Flash-Lite): quicker,
  /// with its own free quota, so they leave the primary's to the coach.
  final String? lightModel;

  /// The model that answered the last request (the primary until then).
  @override
  String model;

  /// Thinking models can take a while on long prompts.
  static const _timeout = Duration(seconds: 90);

  /// Attempts per model.
  static const maxAttempts = 4;

  /// First backoff step; doubles per retry (2s, 4s, 8s) before jitter.
  /// Overloads ("high demand") usually pass within seconds.
  static const backoffBase = Duration(seconds: 2);

  /// Before the single retry of a dropped connection.
  static const _reconnectWait = Duration(milliseconds: 500);

  /// A 429 asking to wait longer than this is treated as "limit reached".
  static const maxRetryDelay = Duration(seconds: 20);

  static Uri _url(String model) =>
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');

  @override
  Future<String> generate(LlmRequest request) async {
    final reply = await respond(request);
    if (reply.text.isEmpty) throw const LlmUnavailable('empty reply');
    return reply.text;
  }

  @override
  Future<LlmReply> respond(LlmRequest request) async {
    if (_apiKey.isEmpty) throw const LlmMissingKey();

    final models = {if (request.light) ?lightModel, _primary, ...fallbackModels}.toList();
    for (final (i, candidate) in models.indexed) {
      final body = requestBody(
        request,
        thinkingLevel: candidate == _primary ? thinkingLevel : null,
      );
      try {
        final reply = await _withRetries(candidate, jsonEncode(body));
        model = candidate;
        if (reply.usage case final usage?) debugPrint('Gemini $candidate: $usage');
        return reply;
      } on LlmFailure catch (failure) {
        // Still overloaded after the retries, or this model's free quota is
        // used up (each model has its own): try the next model, if any.
        final next = failure is LlmUnavailable || failure is LlmRateLimited;
        if (!next || i == models.length - 1) rethrow;
      }
    }
    throw const LlmUnavailable(); // Not reached: the last model rethrows.
  }

  /// The `generateContent` body for [request], thinking at [thinkingLevel]
  /// when given.
  static Map<String, Object?> requestBody(LlmRequest request, {String? thinkingLevel}) => {
    if (request.system != null)
      'systemInstruction': {
        'parts': [
          {'text': request.system},
        ],
      },
    'contents': [for (final message in request.messages) _content(message)],
    if (request.tools.isNotEmpty) ...{
      'tools': [
        {
          'functionDeclarations': [
            for (final tool in request.tools)
              {
                'name': tool.name,
                'description': tool.description,
                'parameters': ?_parameters(tool.parameters),
              },
          ],
        },
      ],
      'toolConfig': {
        'functionCallingConfig': {
          'mode': switch (request.toolMode) {
            LlmToolMode.auto => 'AUTO',
            LlmToolMode.none => 'NONE',
          },
        },
      },
    },
    'generationConfig': {
      'temperature': request.temperature,
      if (request.mediaResolution case final resolution?)
        'mediaResolution': 'MEDIA_RESOLUTION_${resolution.name.toUpperCase()}',
      if (thinkingLevel != null && thinkingLevel.isNotEmpty)
        'thinkingConfig': {'thinkingLevel': thinkingLevel},
      if (request.jsonSchema != null) ...{
        'responseMimeType': 'application/json',
        'responseJsonSchema': request.jsonSchema,
      },
    },
  };

  /// A tool's [schema] for Gemini's `parameters` field, which rejects
  /// `additionalProperties`; nothing for a tool without arguments.
  static Map<String, Object?>? _parameters(Map<String, Object?>? schema) {
    if (schema == null) return null;
    if (schema['properties'] case final Map<Object?, Object?> properties when properties.isEmpty) {
      return null;
    }
    return withoutAdditionalProperties(schema);
  }

  static Object? _content(LlmMessage message) {
    // A model turn goes back exactly as Gemini sent it (with its signatures).
    if (message.raw != null) return message.raw;
    return {
      'role': message.role == LlmRole.user ? 'user' : 'model',
      'parts': [
        for (final image in message.images)
          {
            'inlineData': {'mimeType': image.mimeType, 'data': base64Encode(image.bytes)},
          },
        if (message.text.isNotEmpty) {'text': message.text},
        for (final call in message.toolCalls)
          {
            'functionCall': {'name': call.name, 'args': call.args, 'id': ?call.id},
          },
        for (final result in message.toolResults)
          {
            'functionResponse': {
              'name': result.call.name,
              'id': ?result.call.id,
              'response': result.result,
            },
          },
      ],
    };
  }

  Future<LlmReply> _withRetries(String model, String body) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _attempt(model, body);
      } on _Retryable catch (retry) {
        if (attempt >= (retry.once ? 2 : maxAttempts)) throw retry.failure;
        await _wait(retry.after ?? backoff(attempt));
      }
    }
  }

  /// One request. Throws [_Retryable] for failures worth another try.
  Future<LlmReply> _attempt(String model, String body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _url(model),
            headers: {'x-goog-api-key': _apiKey, 'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      // Already a long wait: trying again would keep the player waiting more.
      throw const LlmOffline();
    } on http.ClientException {
      // One quick retry for a connection dropped mid-request (common on
      // phones); with no connection at all, it fails within a second.
      throw const _Retryable(LlmOffline(), after: _reconnectWait, once: true);
    }

    switch (response.statusCode) {
      case 200:
        return parseReply(utf8.decode(response.bodyBytes));
      case 400
          when response.body.contains('API_KEY_INVALID') ||
              response.body.contains('API key not valid'):
      case 401 || 403:
        throw const LlmInvalidKey();
      case 429:
        final delay = retryDelay(response.body);
        // A long wait means the quota (often the daily one) is used up.
        if (delay != null && delay > maxRetryDelay) throw const LlmRateLimited();
        throw _Retryable(
          const LlmRateLimited(),
          after: delay == null ? null : delay + _jitter(const Duration(milliseconds: 500)),
        );
      case 500 || 502 || 503 || 504:
        throw _Retryable(LlmUnavailable('HTTP ${response.statusCode}'));
      default:
        throw LlmUnavailable('HTTP ${response.statusCode}');
    }
  }

  /// Wait before retry [attempt] (1-based): the step doubles each time, and a
  /// random half of it is dropped ("equal jitter"), so clients spread out.
  Duration backoff(int attempt) {
    final step = backoffBase * pow(2, attempt - 1);
    return step * 0.5 + _jitter(step * 0.5);
  }

  Duration _jitter(Duration max) => max * _random.nextDouble();

  /// The wait Gemini asks for in a 429 (`RetryInfo.retryDelay`, e.g. `"7s"`).
  static Duration? retryDelay(String body) {
    final match = RegExp(r'"retryDelay"\s*:\s*"([\d.]+)s"').firstMatch(body);
    final seconds = match == null ? null : double.tryParse(match[1]!);
    return seconds == null ? null : Duration(milliseconds: (seconds * 1000).round());
  }

  /// The model's turn in a `generateContent` response: its text (without
  /// the "thought" parts of thinking models), any tool calls, and the tokens
  /// used.
  static LlmReply parseReply(String body) {
    final Map<String, Object?> json;
    try {
      json = jsonDecode(body) as Map<String, Object?>;
    } on FormatException {
      throw const LlmUnavailable('not JSON');
    }
    final blocked = (json['promptFeedback'] as Map<String, Object?>?)?['blockReason'];
    if (blocked != null) throw LlmUnavailable('blocked: $blocked');

    final candidates = json['candidates'] as List<Object?>? ?? const [];
    final content = candidates.isEmpty
        ? null
        : (candidates.first as Map<String, Object?>)['content'] as Map<String, Object?>?;
    final parts = (content?['parts'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .where((part) => part['thought'] != true)
        .toList();
    final text = parts.map((part) => part['text']).whereType<String>().join();
    final calls = [
      for (final part in parts)
        if (part['functionCall'] case final Map<String, Object?> call)
          LlmToolCall(
            name: call['name'] as String? ?? '',
            args: call['args'] as Map<String, Object?>? ?? const {},
            id: call['id'] as String?,
          ),
    ];
    if (text.isEmpty && calls.isEmpty) throw const LlmUnavailable('empty reply');
    return LlmReply(
      message: LlmMessage.model(text, toolCalls: calls, raw: content),
      usage: _usage(json['usageMetadata']),
    );
  }

  static LlmUsage? _usage(Object? metadata) {
    if (metadata is! Map<String, Object?>) return null;
    int count(String key) => (metadata[key] as num?)?.toInt() ?? 0;
    return LlmUsage(
      input: count('promptTokenCount'),
      cached: count('cachedContentTokenCount'),
      output: count('candidatesTokenCount'),
      thinking: count('thoughtsTokenCount'),
    );
  }
}

/// A failure that another attempt might fix, after [after] (or the backoff).
class _Retryable implements Exception {
  const _Retryable(this.failure, {this.after, this.once = false});

  final LlmFailure failure;
  final Duration? after;

  /// Worth one more try only, rather than [GeminiClient.maxAttempts].
  final bool once;
}

/// The app's language model: Gemini with the player's key, on the models
/// [geminiModels] picks. A new key (saved or removed in Settings) or a new
/// remote config builds a new client.
final llmClientProvider = Provider<LlmClient>((ref) {
  final (:model, :fallbacks, :thinkingLevel) = geminiModels(
    ApiKeys.geminiModelOverridden ? null : ref.watch(remoteConfigProvider.select((c) => c.models)),
  );
  return GeminiClient(
    apiKey: ref.watch(geminiKeyProvider),
    model: model,
    thinkingLevel: thinkingLevel,
    fallbackModels: fallbacks,
    lightModel: ApiKeys.geminiFallbackModel,
  );
});

/// The models to use: the [remote] ones where given, else the built-in ones.
/// The built-in models always stay as fallbacks, so a remote model name that
/// Gemini doesn't know (a typo, a retired model) costs one failed request,
/// never the AI features.
({String model, List<String> fallbacks, String thinkingLevel}) geminiModels(RemoteModels? remote) {
  final model = remote?.model ?? ApiKeys.geminiModel;
  return (
    model: model,
    fallbacks: {
      ?remote?.fallbackModel,
      ApiKeys.geminiModel,
      ApiKeys.geminiFallbackModel,
    }.where((m) => m != model).toList(),
    thinkingLevel: remote?.thinkingLevel ?? ApiKeys.geminiThinkingLevel,
  );
}

/// Whether there's a key; the AI features are offered only then.
final llmConfiguredProvider = Provider<bool>((ref) => ref.watch(geminiKeyProvider).isNotEmpty);
