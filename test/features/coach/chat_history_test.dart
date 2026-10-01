import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/chat_repository.dart';
import 'package:rooksight/features/coach/chats.dart';
import 'package:rooksight/features/coach/coach_controller.dart';
import 'package:rooksight/features/coach/domain/coach_agent.dart';
import 'package:rooksight/features/coach/domain/coach_chat.dart';
import 'package:rooksight/features/coach/domain/coach_move.dart';
import 'package:rooksight/features/coach/domain/coach_tools.dart';
import 'package:rooksight/features/review/domain/move_review.dart';

void main() {
  // A Tuesday.
  final now = DateTime(2026, 9, 29, 18);

  group('labels', () {
    test('when a chat was last active', () {
      expect(chatWhen(DateTime(2026, 9, 29, 9), now), 'Today');
      expect(chatWhen(DateTime(2026, 9, 28, 23), now), 'Yesterday');
      expect(chatWhen(DateTime(2026, 9, 26), now), 'Sat');
      expect(chatWhen(DateTime(2026, 9, 19), now), '19 Sep');
      expect(chatWhen(DateTime(2025, 12, 1), now), '1 Dec 2025');
    });

    test('day dividers', () {
      expect(dayDivider(DateTime(2026, 9, 29), now), 'Today');
      expect(dayDivider(DateTime(2026, 9, 26), now), 'Sat 26 Sep');
    });

    test('groups: this week, then earlier', () {
      StoredChat chat(int id, DateTime at) => StoredChat(
        id: id,
        title: '$id',
        createdAt: at,
        updatedAt: at,
        messageCount: 2,
        scopeLabel: 'Your recent games',
      );
      final (:thisWeek, :earlier) = groupChats([
        chat(1, DateTime(2026, 9, 29)),
        chat(2, DateTime(2026, 9, 23)),
        chat(3, DateTime(2026, 9, 22)),
      ], now);
      expect([for (final c in thisWeek) c.id], [1, 2]);
      expect([for (final c in earlier) c.id], [3]);
    });

    test('titles are the first question, cut to fit', () {
      expect(CoachMemory.titleFor('  Why   do I lose? '), 'Why do I lose?');
      final long = CoachMemory.titleFor('a' * 200);
      expect(long.length, CoachMemory.titleLength);
      expect(long, endsWith('…'));
    });
  });

  group('saving and reading back', () {
    test('a question keeps the game or move it was about', () {
      const focus = CoachFocus(gameId: 3, index: 12, label: '7. Bg5');
      final message = questionMessage('Why?', focus, now);
      final back = focusOf(message)!;
      expect((back.gameId, back.index, back.label), (3, 12, '7. Bg5'));
      expect(focusOf(questionMessage('Why?', null, now)), isNull);
    });

    test('an answer keeps its headline, finished steps and move card', () {
      final move = CoachMove(
        gameId: 3,
        index: 3,
        label: '2. g4',
        quality: MoveQuality.blunder,
        best: 'd4',
        fen: 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq - 0 2',
        lastMove: Move.parse('g2g4')!,
        orientation: Side.white,
        opponent: 'Stockfish 1600',
        playedAt: DateTime(2026, 9, 26),
      );
      final message = answerMessage(
        CoachAnswer(headline: 'Point', body: 'Evidence.', tryThis: 'Habit', move: move),
        const [AgentStep('Checked your games', detail: '20 games', done: true), AgentStep('…')],
        now,
      );
      expect(message.body, contains('Evidence.'));

      final (:answer, :steps) = answerOf(message);
      expect((answer.headline, answer.body, answer.tryThis), ('Point', 'Evidence.', 'Habit'));
      expect(answer.move!.label, '2. g4');
      expect(answer.move!.quality, MoveQuality.blunder);
      expect(answer.move!.lastMove, Move.parse('g2g4'));
      expect(steps.single.label, 'Checked your games', reason: 'unfinished steps are dropped');
      expect(steps.single.done, isTrue);
    });
  });

  test('a chat is full once it passes the token limit', () {
    CoachTurn turn(String text) => CoachTurn(
      question: text,
      at: now,
      answer: CoachAnswer(body: text),
    );
    final small = CoachState(turns: [turn('Short question and answer.')]);
    expect(small.isFull, isFalse);

    final chars = CoachMemory.maxTokens * 4;
    final full = CoachState(turns: [turn('x' * (chars ~/ 2)), turn('y' * (chars ~/ 2))]);
    expect(full.isFull, isTrue);
  });
}
