import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/features/play/domain/game_clock.dart';
import 'package:move_wise/features/play/domain/game_config.dart';

void main() {
  final t0 = DateTime(2026);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  // 3+2 blitz.
  final blitz = TimeControl.options.first;

  test('neither clock runs before White moves', () {
    final clock = GameClock.start(blitz);
    expect(clock.isRunning, isFalse);
    expect(clock.remaining(Side.white, at(60)), const Duration(minutes: 3));
  });

  test("White's first move is free and starts Black's clock", () {
    final clock = GameClock.start(blitz).afterMove(Side.white, at(5));
    expect(clock.running, Side.black);
    expect(clock.remaining(Side.white, at(5)), const Duration(minutes: 3));
    expect(clock.remaining(Side.black, at(15)), const Duration(minutes: 2, seconds: 50));
  });

  test('a move charges the time used and adds the increment', () {
    final clock = GameClock.start(blitz)
        .afterMove(Side.white, at(0))
        .afterMove(Side.black, at(10)) // Black used 10s, +2.
        .afterMove(Side.white, at(40)); // White used 30s, +2.

    expect(clock.remaining(Side.black, at(40)), const Duration(minutes: 2, seconds: 52));
    expect(clock.remaining(Side.white, at(40)), const Duration(minutes: 2, seconds: 32));
    expect(clock.running, Side.black);
  });

  test('remaining time never goes below zero', () {
    final clock = GameClock.start(blitz).afterMove(Side.white, at(0));
    expect(clock.remaining(Side.black, at(1000)), Duration.zero);
  });

  test('stop freezes both clocks', () {
    final clock = GameClock.start(blitz).afterMove(Side.white, at(0)).stop(at(20));
    expect(clock.isRunning, isFalse);
    expect(clock.remaining(Side.black, at(500)), const Duration(minutes: 2, seconds: 40));
  });

  test('resume restarts a side from its stored time', () {
    final paused = GameClock.start(blitz).afterMove(Side.white, at(0)).stop(at(20));
    final resumed = paused.resume(Side.black, at(300)); // Time in background is free.
    expect(resumed.remaining(Side.black, at(310)), const Duration(minutes: 2, seconds: 30));
  });
}
