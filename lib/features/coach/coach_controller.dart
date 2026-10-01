import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_client.dart';
import '../../core/settings/display_settings.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/storage/chat_repository.dart';
import '../../core/storage/game_repository.dart';
import '../../engine/engine_provider.dart';
import '../play/domain/game_controller.dart' show nowProvider;
import 'domain/coach_agent.dart';
import 'domain/coach_chat.dart';
import 'domain/coach_tools.dart';

/// A saved question the AI Coach never answered (the app closed, or the
/// request failed). Asking again is a tap away.
class NotAnswered {
  const NotAnswered();
}

/// One question and what the coach did with it.
@immutable
class CoachTurn {
  const CoachTurn({
    required this.question,
    required this.at,
    this.focus,
    this.steps = const [],
    this.answer,
    this.error,
    this.saved = false,
    this.restored = false,
  });

  final String question;

  /// When it was asked, for the day dividers.
  final DateTime at;
  final CoachFocus? focus;
  final List<AgentStep> steps;
  final CoachAnswer? answer;

  /// Why the question failed: an [LlmFailure], [NotAnswered], or something
  /// unexpected.
  final Object? error;

  /// The question is stored: asking again doesn't store it twice.
  final bool saved;

  /// Read back from a saved chat, not asked in this session.
  final bool restored;

  bool get isRunning => answer == null && error == null;

  CoachTurn copyWith({List<AgentStep>? steps, CoachAnswer? answer, Object? error, bool? saved}) =>
      CoachTurn(
        question: question,
        at: at,
        focus: focus,
        steps: steps ?? this.steps,
        answer: answer ?? this.answer,
        error: error ?? this.error,
        saved: saved ?? this.saved,
        restored: restored,
      );

  /// The question and answer, as the coach remembers them.
  String get asText => [question, ?answer?.asText].join('\n');
}

@immutable
class CoachState {
  const CoachState({this.turns = const [], this.chatId, this.loading = false});

  final List<CoachTurn> turns;

  /// The saved chat; null until the first question is sent.
  final int? chatId;

  /// Reading a saved chat from the phone.
  final bool loading;

  bool get isBusy => turns.isNotEmpty && turns.last.isRunning;

  /// Roughly how many tokens the conversation takes.
  int get tokens => turns.fold(0, (sum, t) => sum + CoachMemory.tokens(t.asText));

  /// Past [CoachMemory.maxTokens]: no more questions in this chat.
  bool get isFull => tokens > CoachMemory.maxTokens;

  CoachState copyWith({List<CoachTurn>? turns, int? chatId, bool? loading}) => CoachState(
    turns: turns ?? this.turns,
    chatId: chatId ?? this.chatId,
    loading: loading ?? this.loading,
  );
}

/// An AI Coach chat: a saved one by id, or a new one (null) that is saved
/// when its first question is sent. Opening a saved chat only reads it from
/// the phone; the AI runs only when a question is sent.
final coachControllerProvider = NotifierProvider.autoDispose
    .family<CoachController, CoachState, int?>(CoachController.new);

class CoachController extends Notifier<CoachState> {
  CoachController(this.openedChatId);

  /// The saved chat this controller opened; null for a new chat.
  final int? openedChatId;

  /// Shared by the chat's questions, so a follow-up may mention moves an
  /// earlier answer's tools reported. A saved chat restores what its tools
  /// verified before.
  CoachTools? _tools;

  @override
  CoachState build() {
    final id = openedChatId;
    if (id == null) return const CoachState();
    Future.microtask(() => _load(id));
    return CoachState(chatId: id, loading: true);
  }

  ChatRepository get _chats => ref.read(chatRepositoryProvider);

  CoachTools get _coachTools => _tools ??= CoachTools(
    games: ref.read(gameRepositoryProvider),
    analyses: ref.read(analysisRepositoryProvider),
    engine: ref.read(chessEngineProvider),
    depth: ref.read(analysisDepthProvider).plies,
  );

  /// Reads the chat back: questions and answers as they were. No AI call.
  Future<void> _load(int id) async {
    final chat = await _chats.chat(id);
    final messages = await _chats.messages(id);
    if (!ref.mounted) return;
    if (chat != null) _coachTools.restore(chat.verified);

    final turns = <CoachTurn>[];
    for (final message in messages) {
      if (message.role == ChatRole.user) {
        turns.add(
          CoachTurn(
            question: message.body,
            at: message.at,
            focus: focusOf(message),
            error: const NotAnswered(),
            saved: true,
            restored: true,
          ),
        );
      } else if (turns.isNotEmpty && turns.last.answer == null) {
        final (:answer, :steps) = answerOf(message);
        turns[turns.length - 1] = CoachTurn(
          question: turns.last.question,
          at: turns.last.at,
          focus: turns.last.focus,
          steps: steps,
          answer: answer,
          saved: true,
          restored: true,
        );
      }
    }
    state = CoachState(turns: turns, chatId: id);
  }

  Future<void> ask(String question, {CoachFocus? focus}) =>
      _ask(question.trim(), focus: focus, saved: false);

  Future<void> _ask(String text, {CoachFocus? focus, required bool saved}) async {
    if (text.isEmpty || state.isBusy || state.loading || state.isFull) return;

    // The recent questions and answers, so follow-ups keep their context.
    final answered = state.turns.where((t) => t.answer != null).toList();
    final history = [
      for (final turn in answered.skip(math.max(0, answered.length - CoachMemory.recentTurns))) ...[
        LlmMessage.user(turn.question),
        LlmMessage.model(turn.answer!.asText),
      ],
    ];
    final now = ref.read(nowProvider)();
    state = state.copyWith(
      turns: [
        ...state.turns,
        CoachTurn(question: text, at: now, focus: focus, saved: saved),
      ],
    );
    final turn = state.turns.length - 1;

    // Leaving the screen mid-answer doesn't lose it: it finishes and saves.
    final keepAlive = ref.keepAlive();
    try {
      if (!saved) await _saveQuestion(text, focus, now);

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
        _track(turn, null);
        await _saveAnswer(answer, turn, tools);
      } on Object catch (error) {
        if (error is! LlmFailure) debugPrint('Coach failed: $error');
        _track(turn, error);
        // Steps still running when it failed never will finish.
        _update(turn, (t) => t.copyWith(error: error, steps: [...t.steps.where((s) => s.done)]));
      }
    } finally {
      keepAlive.close();
    }
  }

  void _track(int turn, Object? error) => ref.read(analyticsProvider).track(Events.coachAsked, {
    'outcome': error is NotAnswered ? 'not_answered' : outcomeOf(error),
    'steps': turn < state.turns.length ? state.turns[turn].steps.length : 0,
  });

  /// Stores the question, creating the chat with the first one.
  Future<void> _saveQuestion(String text, CoachFocus? focus, DateTime at) async {
    try {
      final chats = _chats;
      final id =
          state.chatId ??
          await chats.create(
            NewChat(
              title: CoachMemory.titleFor(text),
              scopeLabel: focus?.isMove == false ? focus!.label : 'Your recent games',
              gameId: focus?.gameId,
            ),
            at,
          );
      await chats.addMessage(id, questionMessage(text, focus, at));
      if (!ref.mounted) return;
      state = state.copyWith(chatId: id);
      final index = state.turns.length - 1;
      _update(index, (t) => t.copyWith(saved: true));
    } on Object catch (error) {
      // The answer still shows; only the history misses it.
      debugPrint('Couldn’t save the question: $error');
    }
  }

  Future<void> _saveAnswer(CoachAnswer answer, int turn, CoachTools tools) async {
    final id = state.chatId;
    if (id == null || turn >= state.turns.length) return;
    try {
      final chats = _chats;
      await chats.addMessage(
        id,
        answerMessage(answer, state.turns[turn].steps, ref.read(nowProvider)()),
      );
      final chat = await chats.chat(id);
      await chats.updateContext(
        id,
        verified: tools.memory,
        // The first move card gives the chat its thumbnail.
        thumbFen: chat?.thumbFen == null ? answer.move?.fen : null,
      );
    } on Object catch (error) {
      debugPrint('Couldn’t save the answer: $error');
    }
  }

  /// Asks the last question again after it failed (or was never answered).
  Future<void> retry() async {
    final last = state.turns.lastOrNull;
    if (last == null || last.error == null) return;
    state = state.copyWith(turns: state.turns.sublist(0, state.turns.length - 1));
    await _ask(last.question, focus: last.focus, saved: last.saved);
  }

  void _update(int index, CoachTurn Function(CoachTurn) change) {
    if (!ref.mounted || index >= state.turns.length) return;
    final turns = [...state.turns];
    turns[index] = change(turns[index]);
    state = state.copyWith(turns: turns);
  }
}
