import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/features/play/domain/game_result.dart';
import 'package:move_wise/features/play/domain/game_rules.dart';
import 'package:move_wise/features/play/domain/game_state.dart';

GameState fromFen(String fen) => GameState.start(Chess.fromSetup(Setup.parseFen(fen)));

/// Plays UCI moves (e.g. `e2e4`, `b7b8q`), failing the test on an illegal one.
GameState playAll(GameState state, List<String> uci) {
  for (final move in uci) {
    final next = state.play(Move.parse(move)!);
    expect(next, isNotNull, reason: '$move should be legal in ${state.position.fen}');
    state = next!;
  }
  return state;
}

String? pieceOn(GameState state, Square square) => state.position.board.pieceAt(square)?.fenChar;

void main() {
  group('castling', () {
    const fen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';

    test('king two squares castles kingside', () {
      final state = playAll(fromFen(fen), ['e1g1']);
      expect(state.moves.last.san, 'O-O');
      expect(pieceOn(state, Square.g1), 'K');
      expect(pieceOn(state, Square.f1), 'R');
    });

    test('dropping the king on its rook castles too', () {
      final state = playAll(fromFen(fen), ['e1h1']);
      expect(state.moves.last.san, 'O-O');
      expect(pieceOn(state, Square.g1), 'K');
      expect(state.moves.last.captured, isNull, reason: 'own rook is not a capture');
    });

    test('queenside', () {
      final state = playAll(fromFen(fen), ['e1c1']);
      expect(state.moves.last.san, 'O-O-O');
      expect(pieceOn(state, Square.d1), 'R');
    });

    test('not through check', () {
      // Black rook on f8 attacks f1.
      final state = fromFen('k4r2/8/8/8/8/8/8/4K2R w K - 0 1');
      expect(state.play(Move.parse('e1g1')!), isNull);
    });
  });

  test('en passant captures the pawn beside it', () {
    final state = playAll(fromFen('rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3'), [
      'e5d6',
    ]);
    final move = state.moves.last;
    expect(move.san, 'exd6');
    expect(move.captured, Role.pawn);
    expect(move.isEnPassant, isTrue);
    expect(pieceOn(state, Square.d5), isNull);
  });

  group('promotion', () {
    const fen = '8/1P4k1/8/8/8/8/6K1/8 w - - 0 1';

    test('to a queen', () {
      final state = playAll(fromFen(fen), ['b7b8q']);
      expect(state.moves.last.san, 'b8=Q');
      expect(pieceOn(state, Square.b8), 'Q');
      expect(state.materialAdvantage(Side.white), 9);
    });

    test('underpromotion to a knight', () {
      final state = playAll(fromFen(fen), ['b7b8n']);
      expect(pieceOn(state, Square.b8), 'N');
    });

    test('needs a piece to promote to', () {
      expect(fromFen(fen).play(Move.parse('b7b8')!), isNull);
    });
  });

  group('game endings', () {
    test('checkmate', () {
      final state = playAll(GameState.start(), ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      expect(state.moves.last.san, 'Qh4#');
      expect(state.result, const GameResult.win(Side.black, GameEndReason.checkmate));
    });

    test('stalemate', () {
      final state = playAll(fromFen('k7/8/8/2Q5/8/8/8/7K w - - 0 1'), ['c5b6']);
      expect(state.result, const GameResult.draw(GameEndReason.stalemate));
    });

    test('insufficient material', () {
      final state = playAll(fromFen('k7/8/8/8/8/8/1q6/K7 w - - 0 1'), ['a1b2']);
      expect(state.result, const GameResult.draw(GameEndReason.insufficientMaterial));
    });

    test('threefold repetition', () {
      final shuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
      final twice = playAll(GameState.start(), shuffle);
      expect(twice.isOver, isFalse, reason: 'start position seen twice');

      final thrice = playAll(twice, shuffle);
      expect(thrice.result, const GameResult.draw(GameEndReason.threefoldRepetition));
    });

    test('50-move rule', () {
      final state = playAll(fromFen('k7/8/8/8/8/8/8/K6R w - - 99 80'), ['h1h2']);
      expect(state.result, const GameResult.draw(GameEndReason.fiftyMoveRule));
    });

    test('a pawn move resets the 50-move count', () {
      final state = playAll(fromFen('k7/8/8/8/8/8/P7/K6R w - - 99 80'), ['a2a3']);
      expect(state.isOver, isFalse);
    });

    test('checkmate on the 100th halfmove beats the 50-move rule', () {
      final state = playAll(fromFen('k7/8/1K6/8/8/8/8/7R w - - 99 80'), ['h1h8']);
      expect(state.result, const GameResult.win(Side.white, GameEndReason.checkmate));
    });

    test('no moves after the game ends', () {
      final state = playAll(GameState.start(), ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      expect(state.play(Move.parse('a2a3')!), isNull);
    });
  });

  group('timeout', () {
    test('loses when the opponent can still mate', () {
      final position = Chess.fromSetup(Setup.parseFen('k7/8/8/8/8/8/1q6/7K w - - 0 1'));
      expect(
        GameRules.onTimeout(position, Side.white),
        const GameResult.win(Side.black, GameEndReason.timeout),
      );
    });

    test('draws when the opponent has only a king', () {
      final position = Chess.fromSetup(Setup.parseFen('k7/8/8/8/8/8/1Q6/7K w - - 0 1'));
      expect(
        GameRules.onTimeout(position, Side.white),
        const GameResult.draw(GameEndReason.timeout),
      );
    });
  });

  group('captures and material', () {
    test('trays list captured pieces, most valuable first', () {
      // 1. e4 d5 2. exd5 Qxd5 3. Nc3 Qxa2 4. Rxa2
      final state = playAll(GameState.start(), [
        'e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3', 'd5a2', 'a1a2', //
      ]);
      expect(state.capturedBy(Side.white), [Role.queen, Role.pawn]);
      expect(state.capturedBy(Side.black), [Role.pawn, Role.pawn]);
      expect(state.materialAdvantage(Side.white), 9 + 1 - 2);
      expect(state.materialAdvantage(Side.black), -8);
    });
  });

  group('undo', () {
    test('takes back plies and clears the result', () {
      final mated = playAll(GameState.start(), ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      final back = mated.undo();
      expect(back.isOver, isFalse);
      expect(back.moves, hasLength(3));
      expect(back.history, hasLength(4));
      expect(back.position.fen, mated.history[3].fen);
    });

    test('never goes before the start', () {
      final state = playAll(GameState.start(), ['e2e4']);
      expect(state.undo(5).moves, isEmpty);
      expect(state.undo(5).position.fen, Chess.initial.fen);
    });
  });
}
