import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/storage/game_repository.dart';
import '../../../core/storage/settings_store.dart';
import '../../play/domain/game_clock.dart';
import '../../play/domain/game_controller.dart' show nowProvider;
import '../../play/domain/game_result.dart';
import '../../play/domain/game_rules.dart';
import '../../play/domain/game_state.dart';
import 'pass_config.dart';
import 'pass_pgn.dart';
import 'pass_session.dart';
import 'unfinished_pass_game.dart';

/// The pass & play game being played. Disposed when its screen closes;
/// starts from [passConfigProvider], or from the saved game when Home's
/// Resume asked for it.
final passControllerProvider = NotifierProvider.autoDispose<PassController, PassSession>(
  PassController.new,
);

class PassController extends Notifier<PassSession> {
  late DateTime Function() _now;
  Timer? _flagTimer;

  @override
  PassSession build() {
    _now = ref.watch(nowProvider);
    final unfinished = ref.read(unfinishedPassGameProvider.notifier);
    final settings = ref.read(settingsStoreProvider);
    final saved = ref.read(resumePassGameProvider).take()
        ? UnfinishedPassGameStore.load(settings)
        : null;
    final session = saved?.resume() ?? _newSession(ref.read(passConfigProvider));

    // Keep the game resumable after every move, and once more when the
    // screen closes (time spent thinking until then counts). A finished game
    // clears it.
    var latest = session;
    listenSelf((previous, next) {
      latest = next;
      if (previous != null && previous.game != next.game) unfinished.save(next, _now());
    });
    ref.onDispose(() {
      _flagTimer?.cancel();
      UnfinishedPassGameStore.write(settings, latest, _now());
    });
    return session;
  }

  PassConfig get _config => state.config;

  PassSession _newSession(PassConfig config) => PassSession(
    config: config,
    game: GameState.start(),
    startedAt: _now(),
    clock: config.timeControl.hasClock ? GameClock.start(config.timeControl) : null,
  );

  /// Plays [move] for the side to move. Returns whether it was played.
  bool play(Move move) {
    if (!state.canMove) return false;
    final next = state.game.play(move);
    if (next == null) return false;

    final now = _now();
    final mover = state.game.turn;
    var clock = state.clock?.afterMove(mover, now);
    if (next.isOver) clock = clock?.stop(now);
    state = state.copyWith(
      game: next,
      clock: () => clock,
      clockTimes: clock == null ? null : [...state.clockTimes, clock.remaining(mover, now)],
      notice: () => null,
    );
    _scheduleFlag();
    if (next.isOver) unawaited(_saveFinishedGame());
    return true;
  }

  /// The player who made the last move asks to take it back.
  void requestTakeback() {
    final side = state.takebackSide;
    if (side == null) return;
    state = state.copyWith(
      request: () => PassRequest(PassRequestKind.takeback, side),
      notice: () => null,
    );
  }

  /// [side] offers a draw.
  void offerDraw(Side side) {
    if (!state.canOfferDraw(side)) return;
    state = state.copyWith(
      request: () => PassRequest(PassRequestKind.draw, side),
      lastDrawOffer: () => (side: side, ply: state.game.moves.length),
      notice: () => null,
    );
  }

  /// The other player answers the waiting offer. Clocks keep running while
  /// it waits.
  void answer({required bool accept}) {
    final request = state.request;
    if (request == null || state.game.isOver) return;
    final answerer = _config.nameOf(request.answerer);
    state = state.copyWith(request: () => null);

    switch ((request.kind, accept)) {
      case (PassRequestKind.draw, true):
        _finish(const GameResult.draw(GameEndReason.agreement));
      case (PassRequestKind.draw, false):
        state = state.copyWith(notice: () => '$answerer declined the draw.');
      case (PassRequestKind.takeback, true):
        _takeBack();
      case (PassRequestKind.takeback, false):
        state = state.copyWith(notice: () => '$answerer declined the takeback.');
    }
  }

  void _takeBack() {
    final game = state.game.undo();
    final now = _now();
    state = state.copyWith(
      game: game,
      // Back at the start, the clocks wait for White's first move again.
      clock: () =>
          game.moves.isEmpty ? state.clock?.stop(now) : state.clock?.resume(game.turn, now),
      clockTimes: state.clockTimes.take(game.moves.length).toList(),
      lastDrawOffer: () => null,
    );
    _scheduleFlag();
  }

  void resign(Side side) => _finish(GameResult.win(side.opposite, GameEndReason.resignation));

  /// Stops both clocks and hides the board.
  void pause() {
    if (state.paused || state.game.isOver) return;
    _flagTimer?.cancel();
    state = state.copyWith(paused: true, clock: () => state.clock?.stop(_now()));
  }

  /// Carries on after a pause. The clocks run again once White has moved.
  void resume() {
    if (!state.paused) return;
    final game = state.game;
    state = state.copyWith(
      paused: false,
      clock: () => game.moves.isEmpty ? state.clock : state.clock?.resume(game.turn, _now()),
    );
    _scheduleFlag();
  }

  /// A new game with the same players, colours swapped.
  void rematch() {
    _flagTimer?.cancel();
    state = _newSession(_config.swapped);
  }

  void _finish(GameResult result) {
    if (state.game.isOver) return;
    _flagTimer?.cancel();
    state = state.copyWith(
      game: state.game.finish(result),
      clock: () => state.clock?.stop(_now()),
      request: () => null,
      paused: false,
    );
    unawaited(_saveFinishedGame());
  }

  /// Arms a timer for the moment the running clock reaches zero.
  void _scheduleFlag() {
    _flagTimer?.cancel();
    final clock = state.clock;
    final side = clock?.running;
    if (clock == null || side == null || state.game.isOver) return;
    _flagTimer = Timer(clock.remaining(side, _now()), _checkFlag);
  }

  void _checkFlag() {
    if (!ref.mounted) return;
    final clock = state.clock;
    final side = clock?.running;
    if (clock == null || side == null || state.game.isOver) return;
    if (clock.remaining(side, _now()) > Duration.zero) {
      _scheduleFlag(); // Fired a little early.
      return;
    }
    _finish(GameRules.onTimeout(state.game.position, side));
  }

  /// Stores the finished game from the first player's side, so it counts in
  /// their stats. Games without a move aren't kept.
  Future<void> _saveFinishedGame() async {
    final session = state;
    final game = session.game;
    final result = game.result;
    if (result == null || game.moves.isEmpty) return;

    final config = session.config;
    ref.read(analyticsProvider).track(Events.passGameFinished, {
      'reason': result.reason.name,
      'moves': game.moves.length,
    });
    final timeControl = config.timeControl;
    final endedAt = _now();
    final startedAt = session.startedAt ?? endedAt;
    try {
      final id = await ref
          .read(gameRepositoryProvider)
          .save(
            GameRecord(
              source: GameSource.passAndPlay,
              pgn: exportPassPgn(session, date: startedAt),
              playerSide: config.firstSide,
              result: result.pgn,
              endReason: result.reason.name,
              opponentName: config.secondName,
              timeControl: timeControl.hasClock
                  ? '${timeControl.initial.inSeconds}+${timeControl.incrementSeconds}'
                  : null,
              plyCount: game.moves.length,
              startedAt: startedAt,
              endedAt: endedAt,
            ),
          );
      if (ref.mounted && state.game == game) {
        state = state.copyWith(savedGameId: id, saveFailed: false);
      }
    } catch (_) {
      if (ref.mounted && state.game == game) state = state.copyWith(saveFailed: true);
    }
  }
}
