import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/features/pass_play/domain/pass_config.dart';
import 'package:move_wise/features/pass_play/domain/pass_session.dart';
import 'package:move_wise/features/pass_play/widgets/pass_copy.dart';
import 'package:move_wise/features/play/domain/game_result.dart';
import 'package:move_wise/features/play/domain/game_state.dart';
import 'package:move_wise/features/play/widgets/result_copy.dart';

GameState _played(List<String> moves) {
  var game = GameState.start();
  for (final uci in moves) {
    game = game.play(Move.parse(uci)!)!;
  }
  return game;
}

void main() {
  group('PassConfig', () {
    test('face-to-face and auto-flip turn each other off', () {
      final table = PassConfig.initial.withFaceToFace(true);
      expect(table.faceToFace, isTrue);
      expect(table.autoFlip, isFalse);

      final flipping = table.withAutoFlip(true);
      expect(flipping.autoFlip, isTrue);
      expect(flipping.faceToFace, isFalse);
    });

    test('names are trimmed, capped and never blank', () {
      expect(PassConfig.cleanName('  Ann ', 'Opponent'), 'Ann');
      expect(PassConfig.cleanName('   ', 'Opponent'), 'Opponent');
      expect(PassConfig.cleanName('A' * 30, 'Opponent'), 'A' * PassConfig.maxNameLength);
    });

    test('a rematch swaps colours, keeping the players', () {
      final config = PassConfig.initial.copyWith(secondName: 'Ann');
      expect(config.nameOf(Side.white), 'You');
      expect(config.swapped.nameOf(Side.white), 'Ann');
    });
  });

  group('result copy', () {
    final config = PassConfig.initial.copyWith(secondName: 'Ann');

    ResultCopy copyOf(GameState game) => passResultCopy(PassSession(config: config, game: game));

    test('checkmate names the winner', () {
      // Fool's mate: Ann (Black) wins.
      final copy = copyOf(_played(['f2f3', 'e7e5', 'g2g4', 'd8h4']));
      expect(copy.overline, 'Checkmate');
      expect(copy.title, 'Ann wins');
      expect(copy.reason, 'Mate with 2…Qh4#.');
      expect(copy.score, '0–1');
      expect(copy.tone, ResultTone.win);
    });

    test('"You" win, not "You wins"', () {
      final game = _played([
        'e2e4',
      ]).finish(const GameResult.win(Side.white, GameEndReason.resignation));
      final copy = copyOf(game);
      expect(copy.title, 'You win');
      expect(copy.reason, 'Ann resigned on move 1.');
    });

    test('timeout names whose clock ran out', () {
      final game = _played([
        'e2e4',
      ]).finish(const GameResult.win(Side.white, GameEndReason.timeout));
      expect(copyOf(game).title, 'You win on time');
      expect(copyOf(game).reason, 'Ann’s clock ran out on move 1.');
    });

    test('offers read naturally for either player', () {
      final session = PassSession(config: config, game: _played(['e2e4', 'e7e5']));
      expect(
        requestTitle(session, const PassRequest(PassRequestKind.draw, Side.white)),
        'You offer a draw',
      );
      expect(
        requestTitle(session, const PassRequest(PassRequestKind.takeback, Side.black)),
        'Ann asks to take back 1…e5',
      );
    });
  });
}
