import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/features/pass_play/domain/pass_config.dart';
import 'package:rooksight/features/pass_play/domain/pass_controller.dart';
import 'package:rooksight/features/pass_play/domain/pass_session.dart';
import 'package:rooksight/features/pass_play/domain/unfinished_pass_game.dart';
import 'package:rooksight/features/play/domain/game_config.dart';
import 'package:rooksight/features/play/domain/game_controller.dart' show nowProvider;
import 'package:rooksight/features/play/domain/game_result.dart';

import '../../../support/fake_game_repository.dart';

/// 3+2: each player's clock.
final _blitz = PassConfig.initial.copyWith(timeControl: TimeControl.passOptions.first);

void main() {
  late SettingsStore store;
  late FakeGameRepository games;

  setUp(() {
    store = SettingsStore.inMemory();
    games = FakeGameRepository();
  });

  /// A container on a fake clock, sharing [store] and [games].
  ProviderContainer containerFor(FakeAsync async) {
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => DateTime(2026).add(async.elapsed)),
        gameRepositoryProvider.overrideWithValue(games),
        settingsStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Runs [body] with a pass & play game set up with [config].
  void withGame(
    void Function(FakeAsync async, ProviderContainer container, PassController controller) body, {
    PassConfig? config,
  }) {
    fakeAsync((async) {
      final container = containerFor(async);
      container.read(passConfigProvider.notifier).set(config ?? _blitz);
      container.listen(passControllerProvider, (_, _) {});
      async.flushMicrotasks();
      body(async, container, container.read(passControllerProvider.notifier));
    });
  }

  PassSession session(ProviderContainer container) => container.read(passControllerProvider);

  void play(PassController controller, String uci) {
    expect(controller.play(Move.parse(uci)!), isTrue, reason: '$uci should be playable');
  }

  Duration left(ProviderContainer container, Side side, FakeAsync async) =>
      session(container).clock!.remaining(side, DateTime(2026).add(async.elapsed));

  group('clocks', () {
    test('both players are timed, one clock at a time', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4'); // Free: the clocks start now.
        async.elapse(const Duration(seconds: 10));
        play(controller, 'e7e5'); // Black used 10s, +2.
        async.elapse(const Duration(seconds: 30));

        expect(left(container, Side.black, async), const Duration(minutes: 2, seconds: 52));
        expect(left(container, Side.white, async), const Duration(minutes: 2, seconds: 30));
        expect(session(container).clock!.running, Side.white);
        expect(session(container).clockTimes, [
          const Duration(minutes: 3),
          const Duration(minutes: 2, seconds: 52),
        ]);
      });
    });

    test('a player whose clock runs out loses on time', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        async.elapse(const Duration(minutes: 3));
        expect(
          session(container).game.result,
          const GameResult.win(Side.white, GameEndReason.timeout),
        );
      });
    });

    test('pausing stops both clocks and blocks moves until resumed', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        controller.pause();
        async.elapse(const Duration(minutes: 10));
        expect(session(container).game.isOver, isFalse);
        expect(controller.play(Move.parse('e7e5')!), isFalse);

        controller.resume();
        async.elapse(const Duration(seconds: 10));
        expect(left(container, Side.black, async), const Duration(minutes: 2, seconds: 50));
        play(controller, 'e7e5');
      });
    });

    test('no clock without a time control', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        expect(session(container).clock, isNull);
        expect(session(container).clockTimes, isEmpty);
      }, config: PassConfig.initial.copyWith(timeControl: TimeControl.none));
    });
  });

  group('takebacks', () {
    test('only the player who just moved may ask', () {
      withGame((async, container, controller) {
        expect(session(container).takebackSide, isNull, reason: 'no move yet');
        play(controller, 'e2e4');
        expect(session(container).takebackSide, Side.white);
      });
    });

    test('allowed by the other player, the move goes back', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        play(controller, 'e7e5');
        controller.requestTakeback();
        expect(session(container).request, const PassRequest(PassRequestKind.takeback, Side.black));
        expect(controller.play(Move.parse('g1f3')!), isFalse, reason: 'waiting for an answer');

        controller.answer(accept: true);
        expect(session(container).game.moves, hasLength(1));
        expect(session(container).clockTimes, hasLength(1));
        expect(session(container).clock!.running, Side.black);
      });
    });

    test('declined, the game goes on with a notice', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        controller.requestTakeback();
        controller.answer(accept: false);
        expect(session(container).game.moves, hasLength(1));
        expect(session(container).notice, 'Opponent declined the takeback.');
      });
    });

    test('never offered when takebacks are off', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        expect(session(container).takebackSide, isNull);
        controller.requestTakeback();
        expect(session(container).request, isNull);
      }, config: _blitz.copyWith(takebacks: false));
    });
  });

  group('draw offers', () {
    test('accepted, the game is drawn by agreement', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        controller.offerDraw(Side.black);
        controller.answer(accept: true);
        expect(session(container).game.result, const GameResult.draw(GameEndReason.agreement));
      });
    });

    test('one offer per player per move', () {
      withGame((async, container, controller) {
        play(controller, 'e2e4');
        controller.offerDraw(Side.black);
        controller.answer(accept: false);
        expect(session(container).notice, 'You declined the draw.');
        expect(session(container).canOfferDraw(Side.black), isFalse);
        expect(session(container).canOfferDraw(Side.white), isTrue);

        play(controller, 'e7e5');
        expect(session(container).canOfferDraw(Side.black), isTrue);
      });
    });
  });

  test('resigning ends the game for that player', () {
    withGame((async, container, controller) {
      play(controller, 'e2e4');
      controller.resign(Side.black);
      expect(
        session(container).game.result,
        const GameResult.win(Side.white, GameEndReason.resignation),
      );
    });
  });

  test("the finished game is saved from the first player's side", () {
    withGame((async, container, controller) {
      // Fool's mate: the first player, Black, wins.
      for (final uci in ['f2f3', 'e7e5', 'g2g4']) {
        play(controller, uci);
      }
      play(controller, 'd8h4');
      async.flushMicrotasks();

      final record = games.games.values.single;
      expect(record.source, GameSource.passAndPlay);
      expect(record.playerSide, Side.black);
      expect(record.outcome, PlayerOutcome.win);
      expect(record.opponentName, 'Ann');
      expect(record.endReason, 'checkmate');
      expect(record.timeControl, '180+2');
      expect(record.pgn, contains('[White "Ann"]'));
      expect(record.pgn, contains('[Black "You"]'));
      expect(record.pgn, contains('[%clk 0:03:00]'));
      expect(session(container).savedGameId, isNotNull);
    }, config: _blitz.copyWith(secondName: 'Ann', firstSide: Side.black));
  });

  test('a rematch swaps colours', () {
    withGame((async, container, controller) {
      play(controller, 'e2e4');
      controller.resign(Side.white);
      controller.rematch();
      expect(session(container).game.moves, isEmpty);
      expect(session(container).config.firstSide, Side.black);
    });
  });

  test('left unfinished, it resumes paused with the same moves and clocks', () {
    fakeAsync((async) {
      final first = containerFor(async);
      first.read(passConfigProvider.notifier).set(_blitz);
      final subscription = first.listen(passControllerProvider, (_, _) {});
      final controller = first.read(passControllerProvider.notifier);
      controller.play(Move.parse('e2e4')!);
      async.elapse(const Duration(seconds: 20));
      subscription.close();
      async.flushMicrotasks();

      final saved = first.read(unfinishedPassGameProvider);
      expect(saved, isNotNull);

      async.elapse(const Duration(hours: 1));
      final second = containerFor(async);
      second.read(resumePassGameProvider).request();
      second.listen(passControllerProvider, (_, _) {});
      final resumed = second.read(passControllerProvider);
      expect(resumed.paused, isTrue);
      expect([for (final m in resumed.game.moves) m.san], ['e4']);
      final now = DateTime(2026).add(async.elapsed);
      expect(resumed.clock!.remaining(Side.black, now), const Duration(minutes: 2, seconds: 40));
    });
  });
}
