import 'package:flutter/foundation.dart';

/// One turn of a conversation with a language model.
@immutable
class LlmMessage {
  const LlmMessage.user(this.text, {this.images = const []})
    : role = LlmRole.user,
      toolCalls = const [],
      toolResults = const [],
      raw = null;

  const LlmMessage.model(this.text, {this.toolCalls = const [], this.raw})
    : role = LlmRole.model,
      toolResults = const [],
      images = const [];

  /// The results of the tools the model asked for in its previous turn.
  const LlmMessage.toolResults(this.toolResults)
    : role = LlmRole.user,
      text = '',
      toolCalls = const [],
      images = const [],
      raw = null;

  final LlmRole role;
  final String text;

  /// Pictures sent with the text (user turns only), e.g. a board photo.
  final List<LlmImage> images;

  /// Tools the model asked to run (model turns only).
  final List<LlmToolCall> toolCalls;
  final List<LlmToolResult> toolResults;

  /// The provider's own form of a model turn, sent back unchanged in later
  /// requests. Gemini needs this: its tool calls carry signatures of the
  /// model's reasoning that must be returned as they came.
  final Object? raw;
}

enum LlmRole { user, model }

/// Image detail. On Gemini 3 an image costs a fixed number of tokens set by
/// this, whatever its pixel size: low 280, medium 560, high (the default)
/// 1120.
enum LlmMediaResolution { low, medium, high }

/// An image in a user turn: encoded bytes and their media type.
@immutable
class LlmImage {
  const LlmImage(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;
}

/// A tool the model may call: a name, what it does, and a JSON Schema for
/// its arguments (null when it takes none).
@immutable
class LlmTool {
  const LlmTool({required this.name, required this.description, this.parameters});

  final String name;
  final String description;
  final Map<String, Object?>? parameters;
}

/// The model asking for [name] to run with [args].
@immutable
class LlmToolCall {
  const LlmToolCall({required this.name, this.args = const {}, this.id});

  final String name;
  final Map<String, Object?> args;

  /// The provider's id for the call, echoed in the result when present.
  final String? id;
}

/// What a tool returned, for the call it answers.
@immutable
class LlmToolResult {
  const LlmToolResult({required this.call, required this.result});

  final LlmToolCall call;
  final Map<String, Object?> result;
}

/// Whether the model may call tools in this turn.
enum LlmToolMode {
  /// The model decides.
  auto,

  /// Tools stay declared but the model must answer in text.
  none,
}

/// A request to a language model. [jsonSchema] asks for JSON matching it.
@immutable
class LlmRequest {
  const LlmRequest({
    required this.messages,
    this.system,
    this.jsonSchema,
    this.temperature = 0.4,
    this.tools = const [],
    this.toolMode = LlmToolMode.auto,
    this.mediaResolution,
  });

  /// How much detail (and how many tokens) each image gets; the model's
  /// default when null.
  final LlmMediaResolution? mediaResolution;

  final String? system;
  final List<LlmMessage> messages;

  /// A JSON Schema the reply must follow; the reply is then JSON text.
  final Map<String, Object?>? jsonSchema;
  final double temperature;
  final List<LlmTool> tools;
  final LlmToolMode toolMode;
}

/// Tokens one request used, as the provider counted them (what it bills).
@immutable
class LlmUsage {
  const LlmUsage({this.input = 0, this.cached = 0, this.output = 0, this.thinking = 0});

  /// The whole prompt, [cached] tokens included.
  final int input;

  /// Prompt tokens served from the provider's cache, billed at a discount.
  final int cached;

  /// The reply itself.
  final int output;

  /// Reasoning before the reply, billed as output.
  final int thinking;

  /// No tokens: the start of a total.
  static const zero = LlmUsage();

  /// Both requests together, e.g. every step of a coach answer.
  LlmUsage operator +(LlmUsage other) => LlmUsage(
    input: input + other.input,
    cached: cached + other.cached,
    output: output + other.output,
    thinking: thinking + other.thinking,
  );

  @override
  bool operator ==(Object other) =>
      other is LlmUsage &&
      other.input == input &&
      other.cached == cached &&
      other.output == output &&
      other.thinking == thinking;

  @override
  int get hashCode => Object.hash(input, cached, output, thinking);

  @override
  String toString() => 'in $input (cached $cached), out $output, thinking $thinking';
}

/// A model's turn: text, tool calls, or both.
@immutable
class LlmReply {
  const LlmReply({required this.message, this.usage});

  /// The turn as it goes back into the conversation.
  final LlmMessage message;

  /// Tokens the request used, when the provider reported them.
  final LlmUsage? usage;

  String get text => message.text;
  List<LlmToolCall> get toolCalls => message.toolCalls;
}

/// Why a model call failed, for the screen to explain.
sealed class LlmFailure implements Exception {
  const LlmFailure();
}

/// No API key configured.
class LlmMissingKey extends LlmFailure {
  const LlmMissingKey();
}

/// The key was rejected.
class LlmInvalidKey extends LlmFailure {
  const LlmInvalidKey();
}

/// Too many requests (e.g. the free tier's limit).
class LlmRateLimited extends LlmFailure {
  const LlmRateLimited();
}

/// No connection, or no answer in time.
class LlmOffline extends LlmFailure {
  const LlmOffline();
}

/// The service failed or replied with something unusable.
class LlmUnavailable extends LlmFailure {
  const LlmUnavailable([this.detail]);
  final String? detail;
}

/// A language model behind an interface, so the provider can be swapped
/// (e.g. to Claude) and tests can use a fake.
abstract interface class LlmClient {
  /// The model's name, stored with what it wrote.
  String get model;

  /// Sends [request] and returns the reply text. Throws [LlmFailure].
  Future<String> generate(LlmRequest request);

  /// Sends [request], which may offer tools, and returns the model's turn:
  /// an answer or tool calls. Throws [LlmFailure].
  Future<LlmReply> respond(LlmRequest request);
}
