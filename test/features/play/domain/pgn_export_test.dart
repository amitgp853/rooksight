import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/engine/elo_levels.dart';
import 'package:rooksight/features/play/domain/game_config.dart';
import 'package:rooksight/features/play/domain/game_result.dart';
import 'package:rooksight/features/play/domain/game_session.dart';
import 'package:rooksight/features/play/domain/game_state.dart';
import 'package:rooksight/features/play/domain/pgn_export.dart';

GameState playAll(GameState state, List<String> uci) {
  for (final move in uci) {
    state = state.play(Move.parse(move)!)!;
  }
  return state;
}

void main() {
  final date = DateTime(2026, 9, 28);
  final config = GameConfig.initial.copyWith(
    level: EloLevel.of(1600),
    playerSide: Side.black,
    timeControl: TimeControl.options.first, // 3+2
  );
  final foolsMate = playAll(GameState.start(), ['f2f3', 'e7e5', 'g2g4', 'd8h4']);

  test('writes standard headers and the moves', () {
    final pgn = exportPgn(
      GameSession(config: config, game: foolsMate),
      date: date,
    );

    expect(pgn, contains('[Event "Rooksight vs Stockfish"]'));
    expect(pgn, contains('[Date "2026.09.28"]'));
    expect(pgn, contains('[White "Stockfish 1600"]'));
    expect(pgn, contains('[Black "You"]'));
    expect(pgn, contains('[WhiteElo "1600"]'));
    expect(pgn, contains('[Result "0-1"]'));
    expect(pgn, contains('[TimeControl "180+2"]'));
    expect(pgn, contains('[Termination "normal"]'));
    expect(pgn, contains('1. f3 e5 2. g4 Qh4# 0-1'));
    expect(pgn, isNot(contains('[FEN')));
  });

  test('reads back into the same moves', () {
    final pgn = exportPgn(
      GameSession(config: config, game: foolsMate),
      date: date,
    );
    final parsed = PgnGame.parsePgn(pgn);
    expect(parsed.moves.mainline().map((m) => m.san), ['f3', 'e5', 'g4', 'Qh4#']);
    expect(parsed.headers['Result'], '0-1');
  });

  test('timeouts are a time forfeit', () {
    final game = GameState.start().finish(const GameResult.win(Side.white, GameEndReason.timeout));
    final pgn = exportPgn(
      GameSession(config: config, game: game),
      date: date,
    );
    expect(pgn, contains('[Termination "time forfeit"]'));
  });

  test('a custom start position is recorded', () {
    const fen = '4k3/8/8/8/8/8/4P3/4K3 w - - 0 40';
    final start = GameState.start(Chess.fromSetup(Setup.parseFen(fen)));
    final game = playAll(start, ['e2e4']);
    final pgn = exportPgn(
      GameSession(
        config: config.copyWith(timeControl: TimeControl.none),
        game: game,
      ),
      date: date,
    );

    expect(pgn, contains('[SetUp "1"]'));
    expect(pgn, contains('[FEN "$fen"]'));
    expect(pgn, contains('[TimeControl "-"]'));
    expect(pgn, contains('40. e4 *'));
  });
}
