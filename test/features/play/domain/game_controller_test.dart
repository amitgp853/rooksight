import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/engine/elo_levels.dart';
import 'package:rooksight/engine/engine_provider.dart';
import 'package:rooksight/features/play/domain/game_config.dart';
import 'package:rooksight/features/play/domain/game_controller.dart';
import 'package:rooksight/features/play/domain/game_result.dart';
import 'package:rooksight/features/play/domain/game_session.dart';

import '../../../support/fake_engine.dart';
import '../../../support/fake_game_repository.dart';

/// Runs [body] with a controller for a game configured by [config], against
/// [engine], on a fake clock.
void withGame(
  FakeEngine engine,
  void Function(FakeAsync async, ProviderContainer container, GameController controller) body, {
  GameConfig Function(GameConfig config)? config,
  FakeGameRepository? games,
}) {
  fakeAsync((async) {
    final container = ProviderContainer(
      overrides: [
        chessEngineProvider.overrideWithValue(engine),
        engineRandomProvider.overrideWithValue(Random(1)),
        nowProvider.overrideWithValue(() => DateTime(2026).add(async.elapsed)),
        gameRepositoryProvider.overrideWithValue(games ?? FakeGameRepository()),
      ],
    );
    addTearDown(container.dispose);
    if (config != null) {
      final notifier = container.read(gameConfigProvider.notifier);
      notifier.set(config(container.read(gameConfigProvider)));
    }
    // Keep the auto-dispose controller alive for the test.
    container.listen(gameControllerProvider, (_, _) {});
    async.flushMicrotasks();
    body(async, container, container.read(gameControllerProvider.notifier));
  });
}

GameSession session(ProviderContainer container) => container.read(gameControllerProvider);

void play(GameController controller, String uci) {
  expect(controller.play(Move.parse(uci)!), isTrue, reason: '$uci should be playable');
}

void main() {
  test('Stockfish replies, but never in under 400ms', () {
    withGame(FakeEngine(), (async, container, controller) {
      play(controller, 'e2e4');

      async.elapse(const Duration(milliseconds: 399));
      expect(session(container).game.moves, hasLength(1));

      async.elapse(const Duration(milliseconds: 1));
      expect(session(container).game.moves, hasLength(2));
      expect(session(container).isPlayerTurn, isTrue);
    });
  });

  test('the thinking indicator shows only when the search takes over 300ms', () {
    withGame(FakeEngine(delay: const Duration(seconds: 1)), (async, container, controller) {
      play(controller, 'e2e4');

      async.elapse(const Duration(milliseconds: 299));
      expect(session(container).engineThinking, isFalse);

      async.elapse(const Duration(milliseconds: 2));
      expect(session(container).engineThinking, isTrue);

      async.elapse(const Duration(milliseconds: 700));
      expect(session(container).engineThinking, isFalse);
      expect(session(container).game.moves, hasLength(2));
    });
  });

  test('a quick reply never shows the indicator', () {
    withGame(FakeEngine(delay: const Duration(milliseconds: 100)), (async, container, controller) {
      final seen = <bool>[];
      container.listen(gameControllerProvider, (_, next) => seen.add(next.engineThinking));
      play(controller, 'e2e4');
      async.elapse(const Duration(seconds: 1));
      expect(seen, isNot(contains(true)));
    });
  });

  test('Stockfish moves first when the player is Black', () {
    final engine = FakeEngine();
    withGame(engine, (async, container, controller) {
      async.elapse(const Duration(milliseconds: 400));
      expect(session(container).game.moves.single.side, Side.white);
      expect(session(container).isPlayerTurn, isTrue);
    }, config: (c) => c.copyWith(playerSide: Side.black));
  });

  test('searches use the chosen level', () {
    final engine = FakeEngine();
    withGame(engine, (async, container, controller) {
      play(controller, 'e2e4');
      async.elapse(const Duration(milliseconds: 400));
      expect(engine.searches.single.limits.limitElo, 2200);
    }, config: (c) => c.copyWith(level: EloLevel.of(2200)));
  });

  test('the player cannot move for Stockfish', () {
    withGame(FakeEngine(), (async, container, controller) {
      play(controller, 'e2e4');
      expect(controller.play(Move.parse('e7e5')!), isFalse);
    });
  });

  group('hint', () {
    test('shows the best move, then clears after the player moves', () {
      final engine = FakeEngine(reply: (_) => [line('g1f3')]);
      withGame(engine, (async, container, controller) {
        controller.requestHint();
        async.elapse(Duration.zero);
        final hint = session(container).hint!;
        expect(hint.move, const NormalMove(from: Square.g1, to: Square.f3));
        expect(hint.text, 'Look at your knight on g1.');
        expect(session(container).hintsUsed, 1);

        play(controller, 'g1f3');
        expect(session(container).hint, isNull);
      });
    });

    test('uses full strength, whatever the level', () {
      final engine = FakeEngine();
      withGame(engine, (async, container, controller) {
        controller.requestHint();
        async.elapse(Duration.zero);
        expect(engine.searches.single.limits.limitElo, isNull);
        expect(engine.searches.single.limits.skillLevel, isNull);
      }, config: (c) => c.copyWith(level: EloLevel.of(400)));
    });
  });

  group('take back', () {
    test('only in practice mode', () {
      withGame(FakeEngine(), (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(milliseconds: 400));
        expect(session(container).canUndo, isFalse);

        controller.setPractice(enabled: true);
        controller.undo();
        expect(session(container).game.moves, isEmpty);
        expect(session(container).isPlayerTurn, isTrue);
      });
    });

    test('while Stockfish is thinking drops its reply', () {
      final engine = FakeEngine(delay: const Duration(seconds: 1));
      withGame(engine, (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(milliseconds: 500));
        controller.undo();
        async.elapse(const Duration(seconds: 2));
        expect(session(container).game.moves, isEmpty);
        expect(session(container).engineThinking, isFalse);
      }, config: (c) => c.copyWith(practice: true));
    });
  });

  test('resigning hands Stockfish the win', () {
    withGame(FakeEngine(), (async, container, controller) {
      controller.resign();
      expect(
        session(container).game.result,
        const GameResult.win(Side.black, GameEndReason.resignation),
      );
    });
  });

  test('rematch starts a fresh game with the same settings', () {
    withGame(FakeEngine(), (async, container, controller) {
      play(controller, 'e2e4');
      async.elapse(const Duration(milliseconds: 400));
      controller.rematch();
      expect(session(container).game.moves, isEmpty);
      expect(session(container).config.level.elo, 1800);
    }, config: (c) => c.copyWith(level: EloLevel.of(1800)));
  });

  test('an engine failure can be retried', () {
    final engine = FakeEngine()..fail = true;
    withGame(engine, (async, container, controller) {
      play(controller, 'e2e4');
      async.elapse(const Duration(milliseconds: 400));
      expect(session(container).engineError, isTrue);

      engine.fail = false;
      controller.retryEngine();
      async.elapse(const Duration(milliseconds: 400));
      expect(session(container).engineError, isFalse);
      expect(session(container).game.moves, hasLength(2));
    });
  });

  group('clock', () {
    // 3+2 blitz.
    GameConfig blitz(GameConfig c) => c.copyWith(timeControl: TimeControl.options.first);

    Duration left(ProviderContainer container, Side side, FakeAsync async) =>
        session(container).clock!.remaining(side, DateTime(2026).add(async.elapsed));

    test("White's first move is free; Stockfish thinks off the clock", () {
      withGame(FakeEngine(delay: const Duration(seconds: 3)), (async, container, controller) {
        async.elapse(const Duration(seconds: 10));
        play(controller, 'e2e4');
        expect(left(container, Side.white, async), const Duration(minutes: 3));
        expect(session(container).clock!.isRunning, isFalse);

        async.elapse(const Duration(seconds: 3)); // Stockfish replies.
        expect(left(container, Side.black, async), const Duration(minutes: 3));
        expect(left(container, Side.white, async), const Duration(minutes: 3));
        expect(session(container).clock!.running, Side.white);
      }, config: blitz);
    });

    test("playing Black, Stockfish's first move starts the player's clock", () {
      withGame(FakeEngine(delay: const Duration(seconds: 3)), (async, container, controller) {
        async.elapse(const Duration(seconds: 3)); // Stockfish opens.
        expect(session(container).game.moves, hasLength(1));
        expect(session(container).clock!.running, Side.black);

        async.elapse(const Duration(seconds: 10));
        expect(left(container, Side.black, async), const Duration(minutes: 2, seconds: 50));
      }, config: (c) => blitz(c).copyWith(playerSide: Side.black));
    });

    test("Stockfish can't lose on time, however long it thinks", () {
      withGame(FakeEngine(delay: const Duration(minutes: 5)), (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(minutes: 5)); // Longer than the 3 minutes.
        expect(session(container).game.isOver, isFalse);
        expect(session(container).game.moves, hasLength(2));
      }, config: blitz);
    });

    test('running out of time loses when Stockfish can still mate', () {
      withGame(FakeEngine(), (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(milliseconds: 400)); // Stockfish replies.
        async.elapse(const Duration(minutes: 3));
        expect(
          session(container).game.result,
          const GameResult.win(Side.black, GameEndReason.timeout),
        );
        expect(session(container).clock!.isRunning, isFalse);
      }, config: blitz);
    });

    test('time in the background is not counted', () {
      withGame(FakeEngine(), (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(milliseconds: 400));
        controller.pauseClock();
        async.elapse(const Duration(minutes: 10));
        expect(session(container).game.isOver, isFalse);

        controller.resumeClock();
        async.elapse(const Duration(seconds: 10));
        expect(left(container, Side.white, async), const Duration(minutes: 2, seconds: 50));
      }, config: blitz);
    });

    test("a reply that lands in the background doesn't start the player's clock", () {
      withGame(FakeEngine(delay: const Duration(seconds: 1)), (async, container, controller) {
        play(controller, 'e2e4');
        controller.pauseClock();
        async.elapse(const Duration(minutes: 5)); // Stockfish replies meanwhile.
        expect(session(container).game.moves, hasLength(2));
        expect(session(container).clock!.isRunning, isFalse);

        controller.resumeClock();
        expect(session(container).clock!.running, Side.white);
      }, config: blitz);
    });

    test('no clock without a time control', () {
      withGame(FakeEngine(), (async, container, controller) {
        expect(session(container).clock, isNull);
      }, config: (c) => c.copyWith(timeControl: TimeControl.none));
    });
  });

  group('draw offer', () {
    // Move 40, White to move, material level.
    final lateEqual = Chess.fromSetup(Setup.parseFen('4k3/4p3/8/8/8/8/4P3/4K3 w - - 0 40'));

    test('declined before move 30, even when equal', () {
      final engine = FakeEngine(reply: (fen) => [line(FakeEngine.firstLegalMove(fen))]);
      withGame(engine, (async, container, controller) {
        controller.offerDraw();
        async.elapse(Duration.zero);
        expect(session(container).game.isOver, isFalse);
        expect(session(container).notice, 'Stockfish declined the draw.');
        expect(session(container).canOfferDraw, isFalse, reason: 'one offer per move');
      });
    });

    test('accepted late in an equal position', () {
      final engine = FakeEngine(reply: (fen) => [line(FakeEngine.firstLegalMove(fen), cp: 10)]);
      withGame(engine, (async, container, controller) {
        controller.offerDraw();
        async.elapse(Duration.zero);
        expect(session(container).game.result, const GameResult.draw(GameEndReason.agreement));
      }, config: (c) => c.copyWith(startPosition: lateEqual));
    });

    test('declined late when Stockfish is better', () {
      // Scores are for the side to move (the player): −2 means Stockfish is 2 up.
      final engine = FakeEngine(reply: (fen) => [line(FakeEngine.firstLegalMove(fen), cp: -200)]);
      withGame(engine, (async, container, controller) {
        controller.offerDraw();
        async.elapse(Duration.zero);
        expect(session(container).game.isOver, isFalse);
      }, config: (c) => c.copyWith(startPosition: lateEqual));
    });

    test('accepted late when Stockfish is worse', () {
      final engine = FakeEngine(reply: (fen) => [line(FakeEngine.firstLegalMove(fen), cp: 300)]);
      withGame(engine, (async, container, controller) {
        controller.offerDraw();
        async.elapse(Duration.zero);
        expect(session(container).game.result, const GameResult.draw(GameEndReason.agreement));
      }, config: (c) => c.copyWith(startPosition: lateEqual));
    });
  });

  group('saving', () {
    test('a finished game is saved once, as PGN', () {
      final games = FakeGameRepository();
      withGame(FakeEngine(), (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(milliseconds: 400));
        controller.resign();
        async.flushMicrotasks();

        final record = games.games.values.single;
        expect(record.source, GameSource.stockfish);
        expect(record.result, '0-1');
        expect(record.endReason, 'resignation');
        expect(record.engineElo, 1600);
        expect(record.plyCount, 2);
        expect(record.pgn, contains('1. e4'));
        expect(session(container).savedGameId, games.games.keys.single);
      }, games: games);
    });

    test('a game with no moves is not kept', () {
      final games = FakeGameRepository();
      withGame(FakeEngine(), (async, container, controller) {
        controller.resign();
        async.flushMicrotasks();
        expect(games.games, isEmpty);
      }, games: games);
    });

    test('a rematch is saved as a new game', () {
      final games = FakeGameRepository();
      withGame(
        FakeEngine(),
        (async, container, controller) {
          play(controller, 'e2e4');
          async.elapse(const Duration(milliseconds: 400));
          play(controller, 'd2d4');
          async.elapse(const Duration(milliseconds: 400));
          controller.resign();
          async.flushMicrotasks();
          final firstId = session(container).savedGameId;

          controller.rematch();
          play(controller, 'e2e4');
          async.elapse(const Duration(milliseconds: 400));
          controller.resign();
          async.flushMicrotasks();

          expect(games.games, hasLength(2));
          expect(session(container).savedGameId, isNot(firstId));
        },
        games: games,
        config: (c) => c.copyWith(practice: true),
      );
    });

    test('a checkmate taken back and replayed updates the same record', () {
      final games = FakeGameRepository();
      // Stockfish (Black) plays into fool's mate: 1. f3 e5 2. g4 Qh4#.
      final replies = ['e7e5', 'd8h4', 'd8h4'];
      var reply = 0;
      final engine = FakeEngine(reply: (_) => [line(replies[reply++])]);
      withGame(
        engine,
        (async, container, controller) {
          play(controller, 'f2f3');
          async.elapse(const Duration(milliseconds: 400));
          play(controller, 'g2g4');
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();
          final id = session(container).savedGameId;
          expect(id, isNotNull);

          controller.undo(); // Back to before 2. g4.
          play(controller, 'g2g4');
          async.elapse(const Duration(milliseconds: 400));
          async.flushMicrotasks();

          expect(games.games, hasLength(1));
          expect(session(container).savedGameId, id);
        },
        games: games,
        config: (c) => c.copyWith(practice: true),
      );
    });

    test('a failed save is reported, not thrown', () {
      final games = FakeGameRepository()..fail = true;
      withGame(FakeEngine(), (async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(milliseconds: 400));
        controller.resign();
        async.flushMicrotasks();
        expect(session(container).saveFailed, isTrue);
        expect(session(container).game.isOver, isTrue);
      }, games: games);
    });
  });
}
