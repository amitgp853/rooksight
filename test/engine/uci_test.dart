import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/engine/uci.dart';

void main() {
  group('parseInfo', () {
    test('reads depth, rank, centipawn score and the variation', () {
      final line = UciParser.parseInfo(
        'info depth 18 seldepth 24 multipv 2 score cp -35 nodes 812345 nps 1200000 '
        'hashfull 120 tbhits 0 time 677 pv e7e5 g1f3 b8c6',
      )!;
      expect(line.depth, 18);
      expect(line.rank, 2);
      expect(line.score, const EngineScore.centipawns(-35));
      expect(line.pv, ['e7e5', 'g1f3', 'b8c6']);
      expect(line.move, 'e7e5');
    });

    test('reads mate scores and defaults to rank 1', () {
      final line = UciParser.parseInfo('info depth 5 score mate -3 pv h7h6 d1h5')!;
      expect(line.rank, 1);
      expect(line.score, const EngineScore.mate(-3));
      expect(line.score.pawns, -100);
    });

    test('keeps promotion moves', () {
      expect(UciParser.parseInfo('info depth 9 score cp 900 pv b7b8q')!.move, 'b7b8q');
    });

    test('ignores lines without a score or variation', () {
      expect(UciParser.parseInfo('info string NNUE evaluation using nn-5af11540bbfe.nnue'), isNull);
      expect(UciParser.parseInfo('info depth 3 currmove e2e4 currmovenumber 1'), isNull);
      expect(UciParser.parseInfo('info depth 10 score cp 20 lowerbound pv'), isNull);
      expect(UciParser.parseInfo('readyok'), isNull);
    });
  });

  group('parseInfo with WDL', () {
    test('reads win/draw/loss chances when UCI_ShowWDL is on', () {
      final line = UciParser.parseInfo(
        'info depth 20 multipv 1 score cp 42 wdl 312 601 87 nodes 1000 pv e2e4 e7e5',
      )!;
      expect(line.wdl, (win: 312, draw: 601, loss: 87));
      expect(line.pv, ['e2e4', 'e7e5']);
    });

    test('is null without them', () {
      expect(UciParser.parseInfo('info depth 5 score cp 10 pv e2e4')!.wdl, isNull);
    });
  });

  group('parseBestMove', () {
    test('reads the move and ignores the ponder move', () {
      expect(UciParser.parseBestMove('bestmove e2e4 ponder e7e5'), 'e2e4');
      expect(UciParser.parseBestMove('bestmove a7a8n'), 'a7a8n');
    });

    test('is null when there is no legal move', () {
      expect(UciParser.parseBestMove('bestmove (none)'), isNull);
    });

    test('is null for other lines', () {
      expect(UciParser.parseBestMove('info depth 1 score cp 0 pv e2e4'), isNull);
    });
  });
}
