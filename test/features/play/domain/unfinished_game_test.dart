import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/features/play/domain/game_config.dart';
import 'package:move_wise/features/play/domain/game_controller.dart';
import 'package:move_wise/features/play/domain/unfinished_game.dart';

import '../../../support/fake_engine.dart';
import '../../../support/fake_game_repository.dart';

void main() {
  late SettingsStore store;

  setUp(() => store = SettingsStore.inMemory());

  /// A container on a fake clock, sharing [store] (the app's storage).
  ProviderContainer containerFor(FakeAsync async) {
    final container = ProviderContainer(
      overrides: [
        chessEngineProvider.overrideWithValue(FakeEngine()),
        engineRandomProvider.overrideWithValue(Random(1)),
        nowProvider.overrideWithValue(() => DateTime(2026).add(async.elapsed)),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        settingsStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Opens the game screen's controller; returns a function that closes it.
  void Function() open(ProviderContainer container, FakeAsync async) {
    final subscription = container.listen(gameControllerProvider, (_, _) {});
    async.flushMicrotasks();
    return () {
      subscription.close();
      async.flushMicrotasks();
    };
  }

  test('every move is saved; a new board with no move is not', () {
    fakeAsync((async) {
      final container = containerFor(async);
      open(container, async);
      expect(container.read(unfinishedGameProvider), isNull);

      container.read(gameControllerProvider.notifier).play(Move.parse('e2e4')!);
      async.elapse(const Duration(seconds: 1)); // Stockfish replies.

      final saved = container.read(unfinishedGameProvider)!;
      expect(saved.moves, hasLength(2));
      expect(saved.moves.first, 'e2e4');
      expect(saved.config.level.elo, GameConfig.initial.level.elo);
    });
  });

  test('leaving and resuming: same position, clocks as they were', () {
    fakeAsync((async) {
      final first = containerFor(async);
      final close = open(first, async);
      first.read(gameControllerProvider.notifier).play(Move.parse('e2e4')!);
      async.elapse(const Duration(seconds: 1)); // Reply, then 0.6 s of thinking.
      final played = [for (final m in first.read(gameControllerProvider).game.moves) m.san];
      final whiteLeft = first
          .read(gameControllerProvider)
          .clock!
          .remaining(Side.white, DateTime(2026).add(async.elapsed));
      close();

      // Hours later, after the app restarted.
      async.elapse(const Duration(hours: 3));
      final second = containerFor(async);
      second.read(resumeGameProvider).request();
      open(second, async);

      final session = second.read(gameControllerProvider);
      expect([for (final m in session.game.moves) m.san], played);
      expect(played, hasLength(2));
      final now = DateTime(2026).add(async.elapsed);
      expect(
        session.clock!.remaining(Side.white, now),
        whiteLeft,
        reason: 'time away is not charged',
      );
      expect(session.clock!.running, Side.white, reason: 'the player’s clock runs again');
    });
  });

  test('without Resume, the game screen starts a new board', () {
    fakeAsync((async) {
      final first = containerFor(async);
      final close = open(first, async);
      first.read(gameControllerProvider.notifier).play(Move.parse('d2d4')!);
      async.elapse(const Duration(seconds: 1));
      close();

      final second = containerFor(async);
      open(second, async);
      expect(second.read(gameControllerProvider).game.moves, isEmpty);
    });
  });

  test('a finished game is no longer resumable', () {
    fakeAsync((async) {
      final container = containerFor(async);
      open(container, async);
      container.read(gameControllerProvider.notifier).play(Move.parse('e2e4')!);
      async.elapse(const Duration(seconds: 1));
      expect(container.read(unfinishedGameProvider), isNotNull);

      container.read(gameControllerProvider.notifier).resign();
      async.flushMicrotasks();
      expect(container.read(unfinishedGameProvider), isNull);
    });
  });

  test('a damaged save is ignored', () {
    store.set('game.unfinished', '{"moves": 3}');
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(unfinishedGameProvider), isNull);
  });
}
