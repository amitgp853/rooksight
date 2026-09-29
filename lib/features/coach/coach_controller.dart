import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_client.dart';
import '../../core/settings/display_settings.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/storage/game_repository.dart';
import '../../engine/engine_provider.dart';
import 'domain/coach_agent.dart';
import 'domain/coach_tools.dart';

/// One question and what the coach did with it.
@immutable
class CoachTurn {
  const CoachTurn({
    required this.question,
    this.focus,
    this.steps = const [],
    this.answer,
    this.error,
  });

  final String question;
  final CoachFocus? focus;
  final List<AgentStep> steps;
  final CoachAnswer? answer;

  /// Why the question failed: an [LlmFailure], or something unexpected.
  final Object? error;

  bool get isRunning => answer == null && error == null;

  CoachTurn copyWith({List<AgentStep>? steps, CoachAnswer? answer, Object? error}) => CoachTurn(
    question: question,
    focus: focus,
    steps: steps ?? this.steps,
    answer: answer ?? this.answer,
    error: error ?? this.error,
  );
}

@immutable
class CoachState {
  const CoachState({this.turns = const []});

  final List<CoachTurn> turns;

  bool get isBusy => turns.isNotEmpty && turns.last.isRunning;
}

/// The coach chat. It lasts while the app is open and isn't saved.
final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);

class CoachController extends Notifier<CoachState> {
  /// Earlier questions sent along for follow-ups.
  static const historyTurns = 3;

  /// Shared by the chat's questions, so a follow-up may mention moves an
  /// earlier answer's tools reported.
  CoachTools? _tools;

  @override
  CoachState build() => const CoachState();

  CoachTools get _coachTools => _tools ??= CoachTools(
    games: ref.read(gameRepositoryProvider),
    analyses: ref.read(analysisRepositoryProvider),
    engine: ref.read(chessEngineProvider),
    depth: ref.read(analysisDepthProvider).plies,
  );

  Future<void> ask(String question, {CoachFocus? focus}) async {
    final text = question.trim();
    if (text.isEmpty || state.isBusy) return;

    final answered = state.turns.where((t) => t.answer != null).toList();
    final history = [
      for (final turn in answered.skip(math.max(0, answered.length - historyTurns))) ...[
        LlmMessage.user(turn.question),
        LlmMessage.model(turn.answer!.asText),
      ],
    ];
    state = CoachState(
      turns: [
        ...state.turns,
        CoachTurn(question: text, focus: focus),
      ],
    );
    final turn = state.turns.length - 1;

    final tools = _coachTools..focus = focus;
    final agent = CoachAgent(ref.read(llmClientProvider), tools);
    try {
      final answer = await agent.ask(
        text,
        history: history,
        onStep: (index, step) => _update(turn, (t) {
          final steps = [...t.steps];
          index < steps.length ? steps[index] = step : steps.add(step);
          return t.copyWith(steps: steps);
        }),
      );
      _update(turn, (t) => t.copyWith(answer: answer));
    } on Object catch (error) {
      if (error is! LlmFailure) debugPrint('Coach failed: $error');
      // Steps still running when it failed never will finish.
      _update(turn, (t) => t.copyWith(error: error, steps: [...t.steps.where((s) => s.done)]));
    }
  }

  /// Asks the last question again after it failed.
  Future<void> retry() async {
    final last = state.turns.lastOrNull;
    if (last == null || last.error == null) return;
    state = CoachState(turns: state.turns.sublist(0, state.turns.length - 1));
    await ask(last.question, focus: last.focus);
  }

  /// Starts a new chat.
  void clear() {
    if (state.isBusy) return;
    _tools = null;
    state = const CoachState();
  }

  void _update(int index, CoachTurn Function(CoachTurn) change) {
    // The chat may have been cleared meanwhile.
    if (index >= state.turns.length) return;
    final turns = [...state.turns];
    turns[index] = change(turns[index]);
    state = CoachState(turns: turns);
  }
}
