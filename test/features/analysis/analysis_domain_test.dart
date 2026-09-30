import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/engine/uci.dart';
import 'package:move_wise/features/analysis/domain/analysis_args.dart';
import 'package:move_wise/features/analysis/domain/analysis_session.dart';
import 'package:move_wise/features/analysis/domain/analysis_text.dart';
import 'package:move_wise/features/analysis/domain/analysis_tree.dart';
import 'package:move_wise/features/review/domain/move_review.dart';

import '../../support/fake_engine.dart';

Move _m(String uci) => Move.parse(uci)!;

/// The tokens' text, joined: `1. e4 e5 2. Nf3`.
String _text(MoveBlock block) => block.tokens.map((t) => t.text).join(' ');

void main() {
  group('AnalysisTree', () {
    test('a main line from UCI, stopping at the first illegal move', () {
      final tree = AnalysisTree.withLine(Chess.initial, ['e2e4', 'e7e5', 'e2e4', 'g1f3']);
      expect(tree.root.end.ply, 2);
      expect(tree.blocks().map(_text), ['1. e4 e5']);
    });

    test('a move already there is followed, a new one becomes a variation', () {
      final tree = AnalysisTree.withLine(Chess.initial, ['e2e4', 'e7e5', 'g1f3']);
      final e4 = tree.root.children.single;
      expect(tree.play(e4, _m('e7e5')), same(e4.children.single));
      final c5 = tree.play(e4, _m('c7c5'))!;
      expect(e4.children, hasLength(2));
      expect(c5.isMainLine, isFalse);
      expect(c5.isVariationStart, isTrue);
      tree.play(c5, _m('g1f3'));

      expect(tree.blocks().map((b) => (b.depth, _text(b))), [
        (0, '1. e4 e5'),
        (1, '1… c5 2. Nf3'),
        (0, '2. Nf3'),
      ]);
    });

    test('promote makes a variation the main line', () {
      final tree = AnalysisTree.withLine(Chess.initial, ['e2e4', 'e7e5']);
      final c5 = tree.play(tree.root.children.single, _m('c7c5'))!;
      tree.promote(c5);
      expect(c5.isMainLine, isTrue);
      expect(tree.blocks().map(_text).first, '1. e4 c5');
    });

    test('delete removes a move and what follows', () {
      final tree = AnalysisTree.withLine(Chess.initial, ['e2e4', 'e7e5', 'g1f3']);
      final e5 = tree.root.children.single.children.single;
      tree.delete(e5);
      expect(tree.root.end.ply, 1);
    });

    test('lineText numbers black moves after a break', () {
      final tree = AnalysisTree.withLine(Chess.initial, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
      final e5 = tree.root.children.single.children.single;
      expect(tree.lineText(e5), '1… e5 2. Nf3 Nc6');
      expect(tree.lineText(tree.root.children.single), '1. e4 e5 2. Nf3 Nc6');
    });
  });

  group('analysis text', () {
    test('engine lines as SAN with move numbers', () {
      final tokens = lineTokens(Chess.initial, ['e2e4', 'e7e5', 'g1f3', 'zzzz']);
      expect(tokens.map((t) => t.text), ['1.', 'e4', 'e5', '2.', 'Nf3']);
      final black = Chess.initial.play(_m('e2e4'));
      expect(lineTokens(black, ['e7e5', 'g1f3']).map((t) => t.text), ['1…', 'e5', '2.', 'Nf3']);
    });

    test('evals signed for White, mates as M', () {
      expect(whiteEvalText(const EngineScore.centipawns(40), Side.white), '+0.4');
      expect(whiteEvalText(const EngineScore.centipawns(40), Side.black), '−0.4');
      expect(whiteEvalText(const EngineScore.mate(3), Side.black), 'M3');
      expect(whiteAhead(const EngineScore.mate(3), Side.black), isFalse);
    });

    test('WDL turned to White’s side, adding up to 100', () {
      expect(whiteWdl((win: 110, draw: 550, loss: 340), Side.black), (
        white: 34,
        draw: 55,
        black: 11,
      ));
    });

    test('material from White’s side', () {
      expect(materialText(Chess.initial), '=');
      final position = Chess.fromSetup(Setup.parseFen('4k3/8/8/8/8/8/8/3QK3 w - - 0 1'));
      expect(materialText(position), '+9');
    });

    test('a threat names what it goes after', () {
      // Black's knight on c6 can jump to a5, hitting the bishop on c4.
      final position = Chess.fromSetup(
        Setup.parseFen('r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 0 7'),
      );
      const threat = EngineLine(rank: 1, depth: 14, score: EngineScore.centipawns(0), pv: ['c6a5']);
      expect(
        threatText(position, threat, viewer: Side.white),
        '…Na5, going after your bishop on c4',
      );
    });
  });

  group('AnalysisArgs', () {
    test('round-trips through a location', () {
      const args = AnalysisArgs(
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        moves: ['e7e5', 'g1f3'],
        ply: 1,
        source: AnalysisSource.game,
        orientation: Side.black,
      );
      final uri = Uri.parse(args.location);
      expect(uri.path, AnalysisArgs.path);
      final back = AnalysisArgs.fromQuery(uri.queryParameters);
      expect(back.fen, args.fen);
      expect(back.moves, args.moves);
      expect(back.ply, 1);
      expect(back.source, AnalysisSource.game);
      expect(back.orientation, Side.black);
    });
  });

  group('AnalysisSession', () {
    test('deepens step by step on the position shown', () async {
      final engine = FakeEngine(
        reply: (fen) => [
          EngineLine(
            rank: 1,
            depth: 12,
            score: const EngineScore.centipawns(30),
            pv: [FakeEngine.firstLegalMove(fen)],
          ),
        ],
      );
      final session = AnalysisSession(engine: engine, tree: AnalysisTree(Chess.initial))..start();
      expect(session.thinking, isTrue);
      await pumpEventQueue();
      expect(engine.searches.map((s) => s.limits.depth), AnalysisSession.depthSteps);
      expect(engine.searches.every((s) => s.limits.lines == AnalysisSession.lineCount), isTrue);
      expect(session.thinking, isFalse);
      expect(session.analysis!.lines.single.score, const EngineScore.centipawns(30));
      session.dispose();
    });

    test('moving on stops the search and starts on the new position', () async {
      final engine = FakeEngine(delay: const Duration(milliseconds: 5));
      final session = AnalysisSession(engine: engine, tree: AnalysisTree(Chess.initial))..start();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      expect(session.play(_m('e2e4')), isTrue);
      expect(engine.stops, greaterThanOrEqualTo(2));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final e4 = session.position.fen;
      expect(engine.searches.last.fen, e4);
      session.dispose();
    });

    test('marks a move once both positions are searched deeply enough', () async {
      // White blunders the queen: before, White is fine; after, down a queen.
      final engine = FakeEngine(
        reply: (fen) {
          final black = fen.contains(' b ');
          return [
            EngineLine(
              rank: 1,
              depth: 20,
              score: EngineScore.centipawns(black ? 900 : 20),
              pv: [FakeEngine.firstLegalMove(fen)],
            ),
          ];
        },
      );
      final start = Chess.fromSetup(Setup.parseFen('4k3/8/8/3p4/8/8/3Q4/4K3 w - - 0 1'));
      final session = AnalysisSession(engine: engine, tree: AnalysisTree(start))..start();
      await pumpEventQueue();
      session.play(_m('d2d4'));
      await pumpEventQueue();
      expect(session.reviewOf(session.current)?.quality, MoveQuality.blunder);

      session.takeBack();
      expect(session.current.isRoot, isTrue);
      expect(session.tree.root.children, isEmpty);
      session.dispose();
    });

    test('the engine switch stops analysis', () async {
      final engine = FakeEngine();
      final session = AnalysisSession(engine: engine, tree: AnalysisTree(Chess.initial))..start();
      session.setEngine(on: false);
      await pumpEventQueue();
      final count = engine.searches.length;
      session.play(_m('e2e4'));
      await pumpEventQueue();
      expect(engine.searches.length, count);
      session.dispose();
    });

    test('checkmate needs no search', () async {
      final engine = FakeEngine();
      final mated = Chess.fromSetup(
        Setup.parseFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'),
      );
      final session = AnalysisSession(engine: engine, tree: AnalysisTree(mated))..start();
      await pumpEventQueue();
      expect(engine.searches, isEmpty);
      expect(session.analysis!.isTerminal, isTrue);
      session.dispose();
    });
  });
}
