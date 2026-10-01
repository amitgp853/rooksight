import 'package:rooksight/core/llm/llm_client.dart';

/// A language model for tests: answers with [reply] (or throws [failure])
/// and records the requests.
///
/// For tool calling, queue turns in [turns]: each [respond] takes the next
/// one, and falls back to [reply] as the answer once they run out.
class FakeLlm implements LlmClient {
  FakeLlm({this.reply = '{}', this.failure, this.usage, List<LlmReply>? turns})
    : turns = turns ?? [];

  String reply;

  /// Tokens reported with [reply].
  LlmUsage? usage;
  LlmFailure? failure;
  final List<LlmReply> turns;
  final requests = <LlmRequest>[];

  @override
  String get model => 'fake-model';

  @override
  Future<String> generate(LlmRequest request) async => (await respond(request)).text;

  @override
  Future<LlmReply> respond(LlmRequest request) async {
    requests.add(request);
    if (failure != null) throw failure!;
    if (turns.isNotEmpty) return turns.removeAt(0);
    return LlmReply(message: LlmMessage.model(reply), usage: usage);
  }
}

/// A model turn that calls [name] with [args].
LlmReply toolCall(String name, [Map<String, Object?> args = const {}]) => LlmReply(
  message: LlmMessage.model(
    '',
    toolCalls: [LlmToolCall(name: name, args: args)],
  ),
);
