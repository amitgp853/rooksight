import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/engine/uci.dart';
import 'package:rooksight/features/play/domain/game_state.dart';
import 'package:rooksight/features/review/domain/game_analysis.dart';
import 'package:rooksight/features/review/domain/move_review.dart';
import 'package:rooksight/features/review/domain/position_eval.dart';

GameState fromFen(String fen, List<String> uci) {
  var state = GameState.start(Chess.fromSetup(Setup.parseFen(fen)));
  for (final move in uci) {
    state = state.play(Move.parse(move)!)!;
  }
  return state;
}

PositionEval eval(int cp, {String best = 'a1a1', int? second, int? mate}) => PositionEval(
  score: mate != null ? EngineScore.mate(mate) : EngineScore.centipawns(cp),
  bestLine: [best],
  secondScore: second == null ? null : EngineScore.centipawns(second),
);

/// Reviews White's 1. e4 given the eval before (White to move) and after
/// (Black to move, so from Black's side).
MoveReview e4(PositionEval before, PositionEval after) => reviewMove(
  GameState.start().play(Move.parse('e2e4')!)!,
  0,
  evalBefore: before,
  evalAfter: after,
);

void main() {
  group('errors', () {
    test('no loss, no mark', () {
      final review = e4(eval(30), eval(-30));
      expect(review.loss, 0);
      expect(review.quality, isNull);
    });

    test('0.5 to 1.0 pawns is an inaccuracy', () {
      expect(e4(eval(30), eval(40)).quality, MoveQuality.inaccuracy); // 0.3 → −0.4
      expect(e4(eval(30), eval(-20)).quality, isNull, reason: 'exactly 0.5 is fine');
    });

    test('1.0 to 2.0 pawns is a mistake', () {
      expect(e4(eval(30), eval(120)).quality, MoveQuality.mistake); // 0.3 → −1.2
    });

    test('over 2.0 pawns is a blunder', () {
      final review = e4(eval(30), eval(300));
      expect(review.quality, MoveQuality.blunder);
      expect(review.loss, closeTo(3.3, 1e-9));
    });

    test('no ?! or ? while still clearly winning', () {
      expect(e4(eval(900), eval(-750)).quality, isNull); // +9 → +7.5
    });

    test('a blunder is flagged even from a winning position', () {
      expect(e4(eval(900), eval(-300)).quality, MoveQuality.blunder); // +9 → +3
    });

    test('evaluations are capped at ±10, mates included', () {
      final review = e4(eval(0, mate: 3), eval(-900)); // #3 counts as +10 → +9
      expect(review.before, 10);
      expect(review.loss, closeTo(1, 1e-9));
      expect(review.quality, isNull, reason: 'still winning');
    });

    test('missing a mate is a blunder', () {
      expect(e4(eval(0, mate: 2), eval(-100)).quality, MoveQuality.blunder); // +10 → +1
    });
  });

  group('good moves', () {
    test('the only good move is !', () {
      final review = e4(eval(50, best: 'e2e4', second: -60), eval(-50));
      expect(review.quality, MoveQuality.best);
    });

    test('a top move among equals gets no mark', () {
      expect(e4(eval(50, best: 'e2e4', second: -30), eval(-50)).quality, isNull, reason: '0.8 gap');
    });

    test('castling counts as the best move in either notation', () {
      final game = fromFen('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1', ['e1g1']);
      final review = reviewMove(
        game,
        0,
        evalBefore: eval(80, best: 'e1g1', second: -40),
        evalAfter: eval(-80),
      );
      expect(review.quality, MoveQuality.best);
    });

    test('a sacrifice that is the only good move is !!', () {
      // Bxh7+: the bishop can be taken by the king or the knight.
      final game = fromFen('6k1/5ppp/5n2/8/8/3B1N2/5PPP/6K1 w - - 0 1', ['d3h7']);
      final review = reviewMove(
        game,
        0,
        evalBefore: eval(150, best: 'd3h7', second: 0),
        evalAfter: eval(-150),
      );
      expect(review.quality, MoveQuality.brilliant);
    });
  });

  group('what is not a good-move mark', () {
    test('escaping check is forced, not !', () {
      // Black is in check from the queen and has one sensible reply.
      final game = fromFen('4k3/8/8/1B6/8/8/8/4K3 b - - 0 1', ['e8e7']);
      final review = reviewMove(
        game,
        0,
        evalBefore: eval(0, best: 'e8e7', second: -200),
        evalAfter: eval(0),
      );
      expect(review.quality, isNull);
    });

    test('a plain recapture is not !', () {
      // 1. e4 d5 2. exd5 Qxd5: the queen takes back on d5.
      final game = fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', [
        'e2e4',
        'd7d5',
        'e4d5',
        'd8d5',
      ]);
      final review = reviewMove(
        game,
        3,
        evalBefore: eval(-100, best: 'd8d5', second: -300),
        evalAfter: eval(0),
      );
      expect(review.quality, isNull);
    });

    test('an only move in a decided position is not !', () {
      final review = e4(eval(500, best: 'e2e4', second: 350), eval(-500));
      expect(review.quality, isNull);
    });

    test('a decided position can still hold a sacrifice (!!)', () {
      final game = fromFen('6k1/5ppp/5n2/8/8/3B1N2/5PPP/6K1 w - - 0 1', ['d3h7']);
      final review = reviewMove(
        game,
        0,
        evalBefore: eval(600, best: 'd3h7', second: 0),
        evalAfter: eval(-600),
      );
      expect(review.quality, MoveQuality.brilliant);
    });

    test('an even trade is not a sacrifice', () {
      // Nxd5 takes a knight; the pawn on e6 takes back. Knight for knight.
      final game = fromFen('4k3/8/4p3/3n4/8/2N5/8/4K3 w - - 0 1', ['c3d5']);
      final review = reviewMove(
        game,
        0,
        evalBefore: eval(50, best: 'c3d5', second: -100),
        evalAfter: eval(-50),
      );
      expect(review.quality, MoveQuality.best);
    });

    test('a defended piece only the king attacks is not a sacrifice', () {
      // Bd7+ lands next to the black king, defended by the rook on d1.
      final game = fromFen('4k3/8/8/8/8/7B/8/3R3K w - - 0 1', ['h3d7']);
      final review = reviewMove(
        game,
        0,
        evalBefore: eval(100, best: 'h3d7', second: -100),
        evalAfter: eval(-100),
      );
      expect(review.quality, MoveQuality.best);
    });
  });

  group('accuracy', () {
    test('a move that keeps the winning chances is 100', () {
      expect(moveAccuracy(0.3, 0.3), 100);
      expect(moveAccuracy(0.3, 0.5), 100);
    });

    test('Lichess’s formula, with its 1-point allowance', () {
      // A 10-point drop in winning chances.
      expect(
        accuracyFromWinPercents(60, 50),
        closeTo(103.1668100711649 * 0.6470 - 3.166924740191411 + 1, 0.01),
      );
    });

    test('a big drop scores low', () {
      expect(moveAccuracy(0.3, -5), lessThan(20));
    });

    test('win chances are 50% at equality and symmetric', () {
      expect(winPercent(0), 50);
      expect(winPercent(2) + winPercent(-2), closeTo(100, 1e-9));
    });
  });

  group('GameAnalysis', () {
    // 1. e4 e5 2. Nf3 Nc6: White plays 1. e4 (fine) and 2. Nf3 (a blunder,
    // for the test); Black's moves are fine.
    final game = fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', [
      'e2e4',
      'e7e5',
      'g1f3',
      'b8c6',
    ]);
    final evals = [eval(30), eval(-30), eval(30), eval(300), eval(-300)];

    test('reviews every move once complete', () {
      final analysis = GameAnalysis(game, evals);
      expect(analysis.isComplete, isTrue);
      expect(analysis.moves, hasLength(4));
      expect(analysis.moves[2].quality, MoveQuality.blunder);
      expect(analysis.counts(Side.white)[MoveQuality.blunder], 1);
    });

    test('works while partial', () {
      final analysis = GameAnalysis(game, evals.take(3).toList());
      expect(analysis.isComplete, isFalse);
      expect(analysis.moves, hasLength(2));
      expect(analysis.whiteEval(2), closeTo(0.3, 1e-9));
      expect(analysis.whiteEval(4), isNull);
    });

    test('White eval flips the side-to-move score', () {
      final analysis = GameAnalysis(game, evals);
      expect(analysis.whiteEval(1), closeTo(0.3, 1e-9)); // Black to move, −0.3 for Black
    });

    test('accuracy is lower for the side that blundered', () {
      final analysis = GameAnalysis(game, evals);
      expect(analysis.accuracy(Side.white)!, lessThan(analysis.accuracy(Side.black)!));
    });

    test('game accuracy weighs a blunder as Lichess does, not as a plain average', () {
      // 1. e4 e5 2. Nf3 Nc6 3. Nd4?? Nxd4: White hangs a knight.
      final hangs = fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', [
        'e2e4',
        'e7e5',
        'g1f3',
        'b8c6',
        'f3d4',
        'c6d4',
      ]);
      final analysis = GameAnalysis(hangs, [
        eval(30),
        eval(-30),
        eval(30),
        eval(-30),
        eval(30),
        eval(300),
        eval(-300),
      ]);
      // Checked against an independent implementation of lila's
      // AccuracyPercent.gameAccuracy (a plain average would say 76.2).
      expect(analysis.accuracy(Side.white), closeTo(44.21, 0.05));
      expect(analysis.accuracy(Side.black), 100);
    });

    test('no accuracy before a move of that side is evaluated', () {
      final analysis = GameAnalysis(game, [eval(30)]);
      expect(analysis.accuracy(Side.white), isNull);
    });

    test('key moments: the player’s marked moves and the opponent’s blunders', () {
      final analysis = GameAnalysis(game, evals);
      expect(analysis.keyMoments(Side.white).map((m) => m.index), [2]);
      // For Black, White's blunder on move 2 was a chance to punish.
      expect(analysis.keyMoments(Side.black).map((m) => m.index), [2]);
    });

    test('key moments keep every blunder, even the last moves of a long game', () {
      final pawnWalk = fromFen(Chess.initial.fen, [
        for (final file in 'abcdefgh'.split('')) ...['${file}2${file}3', '${file}7${file}6'],
        for (final file in 'abcd'.split('')) ...['${file}3${file}4', '${file}6${file}5'],
      ]);
      // +3 for whoever is to move, every time: each move throws away 6 pawns.
      final evals = [for (var i = 0; i < pawnWalk.history.length; i++) eval(300)];
      final analysis = GameAnalysis(pawnWalk, evals);
      final moments = analysis.keyMoments(Side.white);
      expect(moments, hasLength(24));
      expect(moments.every((m) => m.quality == MoveQuality.blunder), isTrue);
      expect(moments.map((m) => m.index), contains(23), reason: 'the last move too');
    });

    test('key moments come costliest first', () {
      final game = fromFen(Chess.initial.fen, ['a2a3', 'a7a6', 'b2b3', 'b7b6']);
      // 1. a3 is a mistake (+0.5 → −0.8), 2. b3 a blunder (−0.8 → −3.0).
      final analysis = GameAnalysis(game, [eval(50), eval(80), eval(-80), eval(300), eval(-300)]);
      expect(analysis.moves[0].quality, MoveQuality.mistake);
      expect(analysis.moves[2].quality, MoveQuality.blunder);
      expect(analysis.keyMoments(Side.white).map((m) => m.index), [2, 0]);
    });

    test('an opponent’s inaccuracy is not a key moment', () {
      // 1. e4 here is an inaccuracy (+0.3 → −0.4) by White.
      final analysis = GameAnalysis(game, [eval(30), eval(40), eval(-40)]);
      expect(analysis.moves.first.quality, MoveQuality.inaccuracy);
      expect(analysis.keyMoments(Side.black), isEmpty);
    });
  });
}
