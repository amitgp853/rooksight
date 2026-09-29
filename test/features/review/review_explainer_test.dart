import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/llm/llm_client.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/engine/uci.dart';
import 'package:move_wise/features/play/domain/pgn_import.dart';
import 'package:move_wise/features/review/domain/game_analysis.dart';
import 'package:move_wise/features/review/domain/moment_facts.dart';
import 'package:move_wise/features/review/domain/move_review.dart';
import 'package:move_wise/features/review/domain/position_eval.dart';
import 'package:move_wise/features/review/domain/review_explainer.dart';

import '../../support/fake_llm.dart';

PositionEval eval(int cp, List<String> line) =>
    PositionEval(score: EngineScore.centipawns(cp), bestLine: line, depth: 16);

/// 1. f3 e5 2. g4 Qh4#, reviewed from White's side.
final game = gameFromPgn('1. f3 e5 2. g4 Qh4# 0-1');
final analysis = GameAnalysis(game, [
  eval(20, ['e2e4']),
  eval(50, ['e7e5']),
  eval(-60, ['d2d4', 'g8f6']),
  const PositionEval(score: EngineScore.mate(1), bestLine: ['d8h4']),
  const PositionEval(score: EngineScore.mate(0), bestLine: []),
]);
final record = GameRecord(
  source: GameSource.stockfish,
  pgn: '',
  playerSide: Side.white,
  result: '0-1',
  engineElo: 1600,
  opponentName: 'Stockfish 1600',
  plyCount: 4,
  startedAt: DateTime(2026),
  endedAt: DateTime(2026),
);
final moments = analysis.keyMoments(Side.white); // 1. f3 (index 0), 2. g4 (index 2)
final facts = [for (final m in moments) factsFor(analysis, m, player: Side.white)];
final f3 = facts.firstWhere((f) => f.index == 0);
final g4 = facts.firstWhere((f) => f.index == 2);

String reply({
  String summary = 'You opened loosely and paid for it at once.',
  List<String> focus = const ['Keep your king’s diagonals closed early.'],
  String verdict = 'A short, sharp lesson in king safety.',
  required List<Map<String, Object?>> moments,
}) => jsonEncode({'summary': summary, 'focus': focus, 'verdict': verdict, 'moments': moments});

/// Facts for a made-up moment, to test the claim checks directly.
MomentFacts madeUp({int replyMaterial = 0, List<String> hanging = const []}) => MomentFacts(
  index: 7,
  move: '4. Bc4',
  byPlayer: true,
  quality: MoveQuality.blunder,
  evalBefore: 0.3,
  evalAfter: -8,
  bestMove: '4. Nf3',
  bestLine: const ['Nf3'],
  replyLine: const ['Qxc4'],
  materialAfterBestLine: 0,
  materialAfterReplyLine: replyMaterial,
  hanging: hanging,
  mateAvailable: null,
  mateAllowed: null,
  phase: 'opening',
  allowedMoves: const {'Bc4', 'Nf3', 'Qxc4'},
);

void main() {
  group('facts', () {
    test('what the blunder allowed: mate in one', () {
      expect(g4.move, '2. g4');
      expect(g4.replyLine, ['Qh4#']);
      expect(g4.mateAllowed, 1);
      expect(g4.bestMove, '2. d4');
      expect(g4.bestLine, ['d4', 'Nf6']);
      expect(g4.phase, 'opening');
      expect(g4.mateIsReal, isTrue);
    });

    test('an inaccuracy with no mate anywhere', () {
      expect(f3.replyLine, ['e5']);
      expect(f3.mateIsReal, isFalse);
    });

    test('hanging pieces: attacked by something cheaper, or undefended', () {
      final position = Chess.fromSetup(Setup.parseFen('k7/8/3p4/2N5/8/8/8/K7 b - - 0 1'));
      expect(hangingPieces(position, Side.white), ['knight on c5']);
    });

    test('material balance counts both sides', () {
      final position = Chess.fromSetup(Setup.parseFen('k7/8/3p4/2N5/8/8/8/K7 b - - 0 1'));
      expect(materialBalance(position, Side.white), 2);
    });

    test('facts go to the model as JSON', () {
      final json = g4.toJson();
      expect(json['what_the_move_allowed'], 'Qh4#');
      expect(json['mate_in_allowed_for_opponent'], 1);
      expect(json['by'], 'player');
    });
  });

  test('one request, with the facts and the richer schema', () async {
    final llm = FakeLlm(reply: reply(moments: []));
    await ReviewExplainer(llm).explain(analysis, record, moments);

    final request = llm.requests.single;
    expect(request.jsonSchema, ReviewExplainer.schema);
    expect(request.messages.single.text, contains('"what_the_move_allowed":"Qh4#"'));
    expect(request.messages.single.text, isNot(contains('"move":"2…Qh4#"')));
  });

  test('keeps grounded explanations, lessons, summary and focus', () {
    final result = ReviewExplainer.checked(
      reply(
        moments: [
          {
            'id': 2,
            'title': 'g4 opened the door to mate',
            'explanation':
                'It left h4 unguarded, and Qh4# followed at once. 2. d4 kept things closed.',
            'lesson': 'Pawn moves in front of your king open lines to it.',
          },
        ],
      ),
      facts,
    );
    expect(result.summary, 'You opened loosely and paid for it at once.');
    expect(result.focus, ['Keep your king’s diagonals closed early.']);
    expect(result.verdict, 'A short, sharp lesson in king safety.');
    expect(result.moments[2]!.explanation, contains('Qh4# followed at once'));
    expect(result.moments[2]!.lesson, 'Pawn moves in front of your king open lines to it.');
  });

  group('claim checks', () {
    test('invented moves are removed', () {
      expect(
        ReviewExplainer.grounded('After g4 the queen comes in. Bb5 would pin the knight.', g4),
        'After g4 the queen comes in.',
      );
    });

    test('"mate" needs a real mate', () {
      expect(
        ReviewExplainer.grounded('This allowed mate in one. It weakened you.', f3),
        'It weakened you.',
      );
      expect(
        ReviewExplainer.grounded('This allowed mate in one.', g4),
        'This allowed mate in one.',
      );
    });

    test('"loses the queen" needs a queen-sized swing', () {
      const claim = 'Bc4 loses the queen after Qxc4.';
      expect(ReviewExplainer.grounded(claim, madeUp(replyMaterial: -1)), '');
      expect(ReviewExplainer.grounded(claim, madeUp(replyMaterial: -9)), claim);
    });

    test('a hanging piece supports "hangs a knight"', () {
      const claim = 'Bc4 hangs a knight.';
      expect(ReviewExplainer.grounded(claim, madeUp()), '');
      expect(ReviewExplainer.grounded(claim, madeUp(hanging: ['knight on e5'])), claim);
    });

    test('a mistake is never praised: the card keeps its plain text', () {
      final result = ReviewExplainer.checked(
        reply(
          moments: [
            {
              'id': 2,
              'title': 'A strong central push',
              'explanation': 'g4 gained space.',
              'lesson': 'x',
            },
          ],
        ),
        facts,
      );
      expect(result.moments, isEmpty);
    });

    test('summary, focus and verdict may not name moves', () {
      final result = ReviewExplainer.checked(
        reply(
          summary: 'You started well. Then g4 lost at once.',
          focus: ['Play Nf3 early.', 'Check your king’s safety.'],
          verdict: 'Nf3 would have saved you.',
          moments: [],
        ),
        facts,
      );
      expect(result.summary, 'You started well.');
      expect(result.focus, ['Check your king’s safety.']);
      expect(result.verdict, isNull);
    });

    test('at most three focus points', () {
      final result = ReviewExplainer.checked(
        reply(focus: ['One.', 'Two.', 'Three.', 'Four.'], moments: []),
        facts,
      );
      expect(result.focus, hasLength(3));
    });
  });

  test('moments that weren’t asked about are ignored', () {
    final result = ReviewExplainer.checked(
      reply(
        moments: [
          {'id': 3, 'title': 'Mate', 'explanation': 'Well played.', 'lesson': ''},
        ],
      ),
      facts,
    );
    expect(result.moments, isEmpty);
  });

  test('a reply that isn’t JSON is an error', () {
    expect(() => ReviewExplainer.checked('Sorry.', facts), throwsA(isA<LlmUnavailable>()));
  });

  test('older saved answers (verdict only) still load', () {
    final old = ReviewExplanations.fromJson({
      'verdict': 'v',
      'moments': [
        {'id': 2, 'title': 't', 'explanation': 'e'},
      ],
    });
    expect(old.summary, isNull);
    expect(old.focus, isEmpty);
    expect(old.moments[2]!.lesson, isNull);
  });

  test('explanations round-trip through JSON', () {
    const original = ReviewExplanations(
      verdict: 'v',
      summary: 's',
      focus: ['f'],
      moments: {2: MomentExplanation(title: 't', explanation: 'e', lesson: 'l')},
    );
    final back = ReviewExplanations.fromJson(original.toJson());
    expect(back.summary, 's');
    expect(back.focus, ['f']);
    expect(back.moments[2]!.lesson, 'l');
  });
}
