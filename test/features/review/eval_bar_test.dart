import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/engine/uci.dart';
import 'package:move_wise/features/review/domain/position_eval.dart';
import 'package:move_wise/features/review/widgets/eval_bar.dart';

PositionEval score(EngineScore score) => PositionEval(score: score, bestLine: const []);

void main() {
  group('label: no sign, the side it sits on says who is better', () {
    test('pawns', () {
      expect(evalLabel(score(const EngineScore.centipawns(120)), Side.white), '1.2');
      expect(evalLabel(score(const EngineScore.centipawns(120)), Side.black), '1.2');
      expect(evalLabel(score(const EngineScore.centipawns(0)), Side.white), '0.0');
    });

    test('mates, for whichever side mates', () {
      expect(evalLabel(score(const EngineScore.mate(3)), Side.white), 'M3');
      expect(evalLabel(score(const EngineScore.mate(2)), Side.black), 'M2');
      expect(evalLabel(score(const EngineScore.mate(-2)), Side.white), 'M2');
    });

    test('a mated position shows the result', () {
      expect(evalLabel(score(const EngineScore.mate(0)), Side.black), '1–0');
      expect(evalLabel(score(const EngineScore.mate(0)), Side.white), '0–1');
    });
  });

  group('the bar', () {
    test('a mate fills it for the side that mates, with no sliver left', () {
      // White to move and mated: all Black.
      expect(EvalBar.whiteShareOf(score(const EngineScore.mate(0)), Side.white), 0);
      // Black to move, mating in 2: all Black.
      expect(EvalBar.whiteShareOf(score(const EngineScore.mate(2)), Side.black), 0);
      // White to move, mating in 1: all White.
      expect(EvalBar.whiteShareOf(score(const EngineScore.mate(1)), Side.white), 1);
    });

    test('an open game never looks decided', () {
      final huge = EvalBar.whiteShareOf(score(const EngineScore.centipawns(900)), Side.white);
      expect(huge, lessThan(1));
      expect(huge, greaterThan(0.9));
      expect(EvalBar.whiteShareOf(null, Side.white), 0.5);
    });
  });

  test('in words, naming the side', () {
    expect(evalSummary(score(const EngineScore.centipawns(-30)), Side.black), 'White +0.3');
    expect(evalSummary(score(const EngineScore.centipawns(150)), Side.black), 'Black +1.5');
    expect(evalSummary(score(const EngineScore.mate(2)), Side.black), 'Black mates in 2');
    expect(evalSummary(score(const EngineScore.centipawns(2)), Side.white), 'equal');
  });
}
