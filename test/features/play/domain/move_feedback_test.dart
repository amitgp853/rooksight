import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/feedback/haptics.dart';
import 'package:move_wise/core/feedback/sound_player.dart';
import 'package:move_wise/features/play/domain/game_state.dart';
import 'package:move_wise/features/play/domain/move_feedback.dart';

GameState fromFen(String fen) => GameState.start(Chess.fromSetup(Setup.parseFen(fen)));

/// Plays [uci] and returns the feedback for its last move.
MoveFeedback feedback(GameState state, List<String> uci, {Side player = Side.white}) {
  for (final move in uci) {
    state = state.play(Move.parse(move)!)!;
  }
  return MoveFeedback.of(state.moves.last, playerSide: player, gameOver: state.isOver);
}

void main() {
  test('a quiet move: move sound, light tap', () {
    expect(feedback(GameState.start(), ['e2e4']), const MoveFeedback(GameSound.move, Haptic.light));
  });

  test('a capture: capture sound, medium', () {
    expect(
      feedback(GameState.start(), ['e2e4', 'd7d5', 'e4d5']),
      const MoveFeedback(GameSound.capture, Haptic.medium),
    );
  });

  test('en passant counts as a capture', () {
    final state = fromFen('rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3');
    expect(feedback(state, ['e5d6']).sound, GameSound.capture);
  });

  test('castling: one castle sound, light', () {
    final state = fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
    expect(feedback(state, ['e1g1']), const MoveFeedback(GameSound.castle, Haptic.light));
  });

  test("Stockfish checking the player's king: check sound, heavy", () {
    // 1. e4 f5 2. Qh5+ played by White against a Black player.
    expect(
      feedback(GameState.start(), ['e2e4', 'f7f5', 'd1h5'], player: Side.black),
      const MoveFeedback(GameSound.check, Haptic.heavy),
    );
  });

  test('the player giving check: check sound, light', () {
    expect(
      feedback(GameState.start(), ['e2e4', 'f7f5', 'd1h5']),
      const MoveFeedback(GameSound.check, Haptic.light),
    );
  });

  test('a mating move: check sound, medium for game over', () {
    expect(
      feedback(GameState.start(), ['f2f3', 'e7e5', 'g2g4', 'd8h4']),
      const MoveFeedback(GameSound.check, Haptic.medium),
    );
  });
}
