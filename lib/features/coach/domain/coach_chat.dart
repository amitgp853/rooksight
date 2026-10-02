// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../../core/storage/chat_repository.dart';
import 'coach_agent.dart';
import 'coach_move.dart';
import 'coach_tools.dart';

/// How much of a chat the AI Coach remembers, and when a chat is full.
abstract final class CoachMemory {
  /// Earlier questions and answers sent along with each new question.
  static const recentTurns = 5;

  /// A chat holds about this many tokens (questions and answers); past that
  /// it's full and the player starts a new one.
  static const maxTokens = 2000;

  /// Roughly how many tokens [text] takes: about four characters each for
  /// English, which is close enough for a limit.
  static int tokens(String text) => (text.length / 4).ceil();

  /// Saved chats are titled by their first question, cut to this length.
  static const titleLength = 80;

  static String titleFor(String question) {
    final text = question.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= titleLength ? text : '${text.substring(0, titleLength - 1).trimRight()}…';
  }
}

/// A question as saved: its text, and the game or move it was about.
StoredMessage questionMessage(String question, CoachFocus? focus, DateTime at) => StoredMessage(
  role: ChatRole.user,
  at: at,
  body: question,
  payload: {
    if (focus != null)
      'focus': {'gameId': focus.gameId, 'index': ?focus.index, 'label': focus.label},
  },
);

/// An answer as saved: plain text for the list and search, and the rest
/// (headline, finished steps, move card) to show it again.
StoredMessage answerMessage(CoachAnswer answer, List<AgentStep> steps, DateTime at) =>
    StoredMessage(
      role: ChatRole.coach,
      at: at,
      body: answer.asText,
      payload: {
        'headline': ?answer.headline,
        'body': answer.body,
        'tryThis': ?answer.tryThis,
        if (answer.offTopic) 'offTopic': true,
        'move': ?answer.move?.toJson(),
        'steps': [
          for (final step in steps.where((s) => s.done))
            {'label': step.label, 'detail': ?step.detail},
        ],
      },
    );

/// A saved question, read back.
CoachFocus? focusOf(StoredMessage question) {
  final focus = question.payload['focus'];
  if (focus is! Map<String, Object?>) return null;
  final gameId = focus['gameId'];
  final label = focus['label'];
  if (gameId is! int || label is! String) return null;
  return CoachFocus(gameId: gameId, index: focus['index'] as int?, label: label);
}

/// A saved answer, read back: never re-run, just shown.
({CoachAnswer answer, List<AgentStep> steps}) answerOf(StoredMessage message) {
  final p = message.payload;
  final answer = p['offTopic'] == true
      ? const CoachAnswer.offTopic()
      : CoachAnswer(
          headline: p['headline'] as String?,
          body: (p['body'] as String?) ?? message.body,
          tryThis: p['tryThis'] as String?,
          move: CoachMove.fromJson(p['move']),
        );
  final steps = [
    for (final step in (p['steps'] as List<Object?>?) ?? const [])
      if (step case {'label': final String label})
        AgentStep(label, detail: step['detail'] as String?, done: true),
  ];
  return (answer: answer, steps: steps);
}
