import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/features/play/domain/game_clock.dart';
import 'package:rooksight/features/play/domain/game_config.dart';

void main() {
  final t0 = DateTime(2026);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  // 3+2 blitz.
  final blitz = TimeControl.options.first;

  group('both sides timed (pass & play)', () {
    GameClock start() => GameClock.start(blitz);

    test("White's first move is free and starts Black's clock", () {
      final clock = start().afterMove(Side.white, at(5));
      expect(clock.running, Side.black);
      expect(clock.remaining(Side.white, at(5)), const Duration(minutes: 3));
      expect(clock.remaining(Side.black, at(15)), const Duration(minutes: 2, seconds: 50));
    });

    test('each move charges the mover, adds the increment and hands over', () {
      final clock = start()
          .afterMove(Side.white, at(0))
          .afterMove(Side.black, at(10)) // Black used 10s, +2.
          .afterMove(Side.white, at(40)); // White used 30s, +2.

      expect(clock.remaining(Side.black, at(40)), const Duration(minutes: 2, seconds: 52));
      expect(clock.remaining(Side.white, at(40)), const Duration(minutes: 2, seconds: 32));
      expect(clock.running, Side.black);
    });

    test('resume restarts either side', () {
      final paused = start().afterMove(Side.white, at(0)).stop(at(20));
      expect(paused.resume(Side.white, at(30)).running, Side.white);
      expect(paused.resume(Side.black, at(30)).running, Side.black);
    });
  });

  group('playing White', () {
    GameClock start() => GameClock.start(blitz, owner: Side.white);

    test('the clock waits for the first move', () {
      final clock = start();
      expect(clock.isRunning, isFalse);
      expect(clock.remaining(Side.white, at(60)), const Duration(minutes: 3));
    });

    test('the first move is free and Stockfish thinks off the clock', () {
      final clock = start().afterMove(Side.white, at(5));
      expect(clock.isRunning, isFalse);
      expect(clock.remaining(Side.white, at(60)), const Duration(minutes: 3));
      expect(clock.remaining(Side.black, at(60)), const Duration(minutes: 3));
    });

    test("Stockfish's reply starts the player's clock", () {
      final clock = start().afterMove(Side.white, at(0)).afterMove(Side.black, at(10));
      expect(clock.running, Side.white);
      expect(clock.remaining(Side.white, at(40)), const Duration(minutes: 2, seconds: 30));
    });

    test('a move charges the time used, adds the increment and stops', () {
      final clock = start()
          .afterMove(Side.white, at(0))
          .afterMove(Side.black, at(10))
          .afterMove(Side.white, at(40)); // Used 30s, +2.

      expect(clock.isRunning, isFalse);
      expect(clock.remaining(Side.white, at(100)), const Duration(minutes: 2, seconds: 32));
    });
  });

  group('playing Black', () {
    GameClock start() => GameClock.start(blitz, owner: Side.black);

    test("Stockfish's first move starts the player's clock", () {
      final clock = start().afterMove(Side.white, at(5));
      expect(clock.running, Side.black);
      expect(clock.remaining(Side.black, at(15)), const Duration(minutes: 2, seconds: 50));
    });

    test("Stockfish's time is never charged", () {
      final clock = start()
          .afterMove(Side.white, at(0))
          .afterMove(Side.black, at(10))
          .afterMove(Side.white, at(500));
      expect(clock.remaining(Side.white, at(500)), const Duration(minutes: 3));
      expect(clock.remaining(Side.black, at(500)), const Duration(minutes: 2, seconds: 52));
    });
  });

  test('remaining time never goes below zero', () {
    final clock = GameClock.start(blitz, owner: Side.black).afterMove(Side.white, at(0));
    expect(clock.remaining(Side.black, at(1000)), Duration.zero);
  });

  test('stop freezes the clock', () {
    final clock = GameClock.start(
      blitz,
      owner: Side.black,
    ).afterMove(Side.white, at(0)).stop(at(20));
    expect(clock.isRunning, isFalse);
    expect(clock.remaining(Side.black, at(500)), const Duration(minutes: 2, seconds: 40));
  });

  test("resume restarts on the player's turn, from the stored time", () {
    final paused = GameClock.start(
      blitz,
      owner: Side.black,
    ).afterMove(Side.white, at(0)).stop(at(20));
    final resumed = paused.resume(Side.black, at(300)); // Time in background is free.
    expect(resumed.remaining(Side.black, at(310)), const Duration(minutes: 2, seconds: 30));
  });

  test("resume on Stockfish's turn leaves the clock stopped", () {
    final paused = GameClock.stopped(
      white: const Duration(minutes: 2),
      black: const Duration(minutes: 3),
      increment: Duration.zero,
      owner: Side.white,
    );
    expect(paused.resume(Side.black, at(0)).isRunning, isFalse);
  });
}
