import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/features/play/domain/game_config.dart';
import 'package:rooksight/features/play/domain/game_result.dart';
import 'package:rooksight/features/play/domain/game_session.dart';
import 'package:rooksight/features/play/domain/game_state.dart';
import 'package:rooksight/features/play/widgets/result_copy.dart';

GameSession finished(GameState game, {Side player = Side.white}) => GameSession(
  config: GameConfig.initial.copyWith(playerSide: player),
  game: game,
);

GameState playAll(GameState state, List<String> uci) {
  for (final move in uci) {
    state = state.play(Move.parse(move)!)!;
  }
  return state;
}

void main() {
  final foolsMate = playAll(GameState.start(), ['f2f3', 'e7e5', 'g2g4', 'd8h4']);

  test('checkmate as the loser', () {
    final copy = ResultCopy.of(finished(foolsMate));
    expect(copy.overline, 'Checkmate');
    expect(copy.title, 'Stockfish won');
    expect(copy.reason, 'Mate after 2…Qh4#.');
    expect(copy.score, '0–1');
    expect(copy.tone, ResultTone.loss);
  });

  test('checkmate as the winner', () {
    final copy = ResultCopy.of(finished(foolsMate, player: Side.black));
    expect(copy.title, 'You won');
    expect(copy.reason, 'You mated with 2…Qh4#.');
    expect(copy.tone, ResultTone.win);
  });

  test('resignation', () {
    final game = GameState.start().finish(
      const GameResult.win(Side.black, GameEndReason.resignation),
    );
    final copy = ResultCopy.of(finished(game));
    expect(copy.title, 'You resigned');
    expect(copy.reason, 'Game ended on move 1.');
  });

  test('timeout draw names who ran out', () {
    final game = GameState.start().finish(const GameResult.draw(GameEndReason.timeout));
    final copy = ResultCopy.of(finished(game));
    expect(copy.tone, ResultTone.draw);
    expect(copy.reason, 'Your clock ran out, but Stockfish can’t mate.');
    expect(copy.score, '½–½');
  });

  test('every ending has copy', () {
    for (final reason in GameEndReason.values) {
      for (final result in [
        GameResult.win(Side.white, reason),
        GameResult.win(Side.black, reason),
        GameResult.draw(reason),
      ]) {
        final copy = ResultCopy.of(finished(foolsMate.undo().finish(result)));
        expect(copy.title, isNotEmpty);
        expect(copy.reason, isNotEmpty);
      }
    }
  });

  test('move labels follow the start position', () {
    final fromBlack = GameState.start(
      Chess.fromSetup(Setup.parseFen('4k3/8/8/8/8/8/4P3/4K3 b - - 0 40')),
    );
    final game = playAll(fromBlack, ['e8d8', 'e2e4']);
    expect(moveLabel(game, 0), '40…Kd8');
    expect(moveLabel(game, 1), '41. e4');
  });
}
