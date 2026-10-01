import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/storage/game_repository.dart';
import '../../../core/storage/settings_store.dart';
import '../../../engine/chess_engine.dart';
import '../../../engine/elo_levels.dart';
import '../../../engine/engine_provider.dart';
import '../../../engine/uci.dart';
import 'game_clock.dart';
import 'game_config.dart';
import 'game_result.dart';
import 'game_rules.dart';
import 'game_session.dart';
import 'game_state.dart';
import 'pgn_export.dart';
import 'unfinished_game.dart';

/// Randomness for the engine's weaker-move choice. Override for tests.
final engineRandomProvider = Provider<Random>((ref) => Random());

/// The current time, for the clocks. Override for tests.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The game being played against Stockfish. Disposed when the game screen
/// closes; starts from [gameConfigProvider].
final gameControllerProvider = NotifierProvider.autoDispose<GameController, GameSession>(
  GameController.new,
);

class GameController extends Notifier<GameSession> {
  /// Stockfish never replies faster than this, so its moves feel deliberate.
  static const minThinkTime = Duration(milliseconds: 400);

  /// The thinking indicator appears only if Stockfish is still searching
  /// after this long, so fast replies don't flicker.
  static const thinkingIndicatorDelay = Duration(milliseconds: 300);

  /// Stockfish considers a draw offer only from this move on…
  static const drawOfferMinMove = 30;

  /// …and accepts when its evaluation is at most this (in pawns, from its side).
  static const drawAcceptEval = 0.3;

  late ChessEngine _engine;
  late Random _random;
  late DateTime Function() _now;

  /// Bumped whenever a pending engine reply or hint becomes stale (move taken
  /// back, game over, screen closed). Async work checks it before applying.
  int _generation = 0;

  Timer? _flagTimer;

  /// Set while the app is in the background: whose clock to restart on return.
  Side? _pausedClock;
  bool _paused = false;

  /// The player paused the game themselves: coming back to the app doesn't
  /// restart the clock, only Resume does.
  bool _userPaused = false;

  @override
  GameSession build() {
    _engine = ref.watch(chessEngineProvider);
    _random = ref.watch(engineRandomProvider);
    _now = ref.watch(nowProvider);
    unawaited(_engine.warmUp().catchError((_) {}));

    // Home's Resume continues the saved game; otherwise a new board.
    final unfinished = ref.read(unfinishedGameProvider.notifier);
    final settings = ref.read(settingsStoreProvider);
    final saved = ref.read(resumeGameProvider).take() ? UnfinishedGameStore.load(settings) : null;
    final session = saved?.resume(_now()) ?? _newSession(ref.read(gameConfigProvider));

    // Keep the game resumable: saved after every move, hint, take-back or
    // mode change, and once more when the screen closes (time spent thinking
    // until then counts). A finished game clears it.
    var latest = session;
    listenSelf((previous, next) {
      latest = next;
      // The first state needs no save: a new board, or the saved game itself.
      if (previous == null) return;
      if (previous.game != next.game ||
          previous.hintsUsed != next.hintsUsed ||
          previous.config != next.config) {
        unfinished.save(next, _now());
      }
    });
    ref.onDispose(() {
      _generation++;
      _flagTimer?.cancel();
      UnfinishedGameStore.write(settings, latest, _now());
    });

    // If it's Stockfish's move (it plays White, or the saved game stopped on
    // its turn), it moves after build returns.
    scheduleMicrotask(_engineTurnIfDue);
    if (saved != null) scheduleMicrotask(_scheduleFlag);
    return session;
  }

  GameConfig get _config => state.config;

  GameSession _newSession(GameConfig config) => GameSession(
    config: config,
    game: GameState.start(config.startPosition),
    startedAt: _now(),
    clock: config.timeControl.hasClock
        ? GameClock.start(config.timeControl, owner: config.playerSide)
        : null,
  );

  /// Plays the player's [move]. Returns whether it was played.
  bool play(Move move) {
    if (!state.isPlayerTurn) return false;
    final next = state.game.play(move);
    if (next == null) return false;
    _applyMove(next, _config.playerSide);
    unawaited(_engineTurnIfDue());
    return true;
  }

  void resign() => _finish(GameResult.win(_config.engineSide, GameEndReason.resignation));

  /// Offers Stockfish a draw. It accepts from move [drawOfferMinMove] when it
  /// isn't better than [drawAcceptEval]; otherwise it declines with a notice.
  Future<void> offerDraw() async {
    if (!state.canOfferDraw) return;
    final game = state.game;
    final generation = _generation;
    state = state.copyWith(drawOfferedAtPly: () => game.moves.length, notice: () => null);

    List<EngineLine> lines;
    try {
      lines = await _engine.search(game.position.fen, fullStrengthLimits);
    } catch (_) {
      lines = const []; // Treated as a decline.
    }
    if (!ref.mounted || generation != _generation || state.game.isOver) return;

    final score = lines.isEmpty ? null : lines.first.score.pawns;
    // Scores are from the side to move; turn them to Stockfish's side.
    final engineEval = score == null ? null : (game.turn == _config.engineSide ? score : -score);
    final accepts =
        engineEval != null &&
        game.position.fullmoves >= drawOfferMinMove &&
        engineEval <= drawAcceptEval;
    if (accepts) {
      _finish(const GameResult.draw(GameEndReason.agreement));
    } else {
      state = state.copyWith(notice: () => 'Stockfish declined the draw.');
    }
  }

  /// Takes back to the player's last turn (practice mode only).
  void undo() {
    if (!state.canUndo) return;
    _generation++; // Drop any engine reply still being computed.
    var game = state.game.undo();
    if (game.turn != _config.playerSide) game = game.undo();
    final now = _now();
    final clock = state.clock;
    state = state.copyWith(
      game: game,
      engineThinking: false,
      hint: () => null,
      notice: () => null,
      // Back at the start, clocks wait for White's first move again.
      clock: () => game.moves.isEmpty ? clock?.stop(now) : clock?.resume(game.turn, now),
    );
    _scheduleFlag();
    unawaited(_engineTurnIfDue());
  }

  void setPractice({required bool enabled}) {
    state = state.copyWith(config: _config.copyWith(practice: enabled));
  }

  /// Same settings, fresh board.
  void rematch() {
    _generation++;
    _flagTimer?.cancel();
    state = _newSession(_config);
    unawaited(_engineTurnIfDue());
  }

  /// Asks Stockfish again after a failed reply.
  void retryEngine() {
    state = state.copyWith(engineError: false);
    unawaited(_engineTurnIfDue());
  }

  /// Stops the clock while the app is in the background.
  void pauseClock() {
    if (_paused) return;
    _paused = true;
    final clock = state.clock;
    if (clock == null || !clock.isRunning) return;
    _pausedClock = clock.running;
    _flagTimer?.cancel();
    state = state.copyWith(clock: () => clock.stop(_now()));
  }

  /// Pauses a timed game: the clock stops and the board is hidden until
  /// [resume].
  void pause() {
    if (!state.canPause || state.paused) return;
    _userPaused = true;
    pauseClock();
    state = state.copyWith(paused: true, hint: () => null);
  }

  void resume() {
    if (!state.paused) return;
    _userPaused = false;
    state = state.copyWith(paused: false);
    resumeClock();
  }

  /// Restarts the clock that was running when the app went to the background.
  void resumeClock() {
    if (!_paused || _userPaused) return;
    _paused = false;
    final side = _pausedClock;
    _pausedClock = null;
    final clock = state.clock;
    if (clock == null || side == null || state.game.isOver) return;
    state = state.copyWith(clock: () => clock.resume(side, _now()));
    _scheduleFlag();
  }

  /// Shows the best move for the player as a brass arrow.
  Future<void> requestHint() async {
    if (!state.isPlayerTurn || state.hint != null) return;
    final generation = _generation;
    final game = state.game;
    final List<EngineLine> lines;
    try {
      lines = await _engine.search(game.position.fen, fullStrengthLimits);
    } catch (_) {
      return; // A missing hint isn't worth an error message.
    }
    if (!ref.mounted || generation != _generation || state.game != game || lines.isEmpty) {
      return;
    }
    final move = Move.parse(lines.first.move);
    if (move is! NormalMove) return;
    state = state.copyWith(
      hint: () => Hint(move: move, text: hintText(game.position, move)),
      hintsUsed: state.hintsUsed + 1,
    );
  }

  /// Records a move by [mover] and hands the clock over.
  void _applyMove(GameState next, Side mover) {
    final now = _now();
    var clock = state.clock?.afterMove(mover, now);
    if (next.isOver) {
      clock = clock?.stop(now);
    } else if (_paused && clock != null) {
      // Stockfish answered while the app was away: don't start the player's
      // clock until they are back.
      _pausedClock = clock.running;
      clock = clock.stop(now);
    }
    state = state.copyWith(
      game: next,
      clock: () => clock,
      engineThinking: false,
      hint: () => null,
      notice: () => null,
    );
    _scheduleFlag();
    if (next.isOver) unawaited(_saveFinishedGame());
  }

  /// Ends the game now (resignation, agreed draw, timeout).
  void _finish(GameResult result) {
    if (state.game.isOver) return;
    _generation++;
    _flagTimer?.cancel();
    state = state.copyWith(
      game: state.game.finish(result),
      clock: () => state.clock?.stop(_now()),
      engineThinking: false,
      hint: () => null,
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

  /// Stores the finished game. A practice game that ends again after a
  /// take-back replaces its earlier record. Games without a move aren't kept.
  Future<void> _saveFinishedGame() async {
    final session = state;
    final game = session.game;
    final result = game.result;
    if (result == null || game.moves.isEmpty) return;

    final config = session.config;
    // Counted once: not again when a practice game ends after a take-back.
    if (session.savedGameId == null) {
      ref.read(analyticsProvider).track(Events.gameFinished, {
        'elo': config.level.elo,
        'result': switch (result.pgn) {
          '1/2-1/2' => 'draw',
          '1-0' when config.playerSide == Side.white => 'win',
          '0-1' when config.playerSide == Side.black => 'win',
          _ => 'loss',
        },
        'reason': result.reason.name,
        'practice': config.practice,
      });
    }
    final timeControl = config.timeControl;
    final endedAt = _now();
    final startedAt = session.startedAt ?? endedAt;
    try {
      final id = await ref
          .read(gameRepositoryProvider)
          .save(
            GameRecord(
              source: GameSource.stockfish,
              pgn: exportPgn(session, date: startedAt),
              playerSide: config.playerSide,
              result: result.pgn,
              endReason: result.reason.name,
              engineElo: config.level.elo,
              opponentName: 'Stockfish ${config.level.elo}',
              timeControl: timeControl.hasClock
                  ? '${timeControl.initial.inSeconds}+${timeControl.incrementSeconds}'
                  : null,
              practice: config.practice,
              hintsUsed: session.hintsUsed,
              plyCount: game.moves.length,
              startedAt: startedAt,
              endedAt: endedAt,
            ),
            id: session.savedGameId,
          );
      if (ref.mounted && state.game == game) {
        state = state.copyWith(savedGameId: id, saveFailed: false);
      }
    } catch (_) {
      if (ref.mounted && state.game == game) state = state.copyWith(saveFailed: true);
    }
  }

  Future<void> _engineTurnIfDue() async {
    if (!ref.mounted) return;
    final game = state.game;
    if (game.isOver || game.turn != _config.engineSide || state.engineError) return;

    final generation = ++_generation;
    bool isCurrent() => ref.mounted && generation == _generation;

    // Show the indicator only if the search itself is slow, not during the
    // minimum think time (that would flash it before every reply).
    var searching = true;
    final indicator = Timer(thinkingIndicatorDelay, () {
      if (searching && isCurrent()) state = state.copyWith(engineThinking: true);
    });
    try {
      final search = _engine
          .search(game.position.fen, _config.level.searchLimits)
          .whenComplete(() => searching = false);
      final (lines, _) = await (search, Future<void>.delayed(minThinkTime)).wait;
      if (!isCurrent()) return;
      final uci = _config.level.chooseMove(lines, _legalMoves(game.position), _random);
      final next = uci == null ? null : game.play(Move.parse(uci)!);
      if (next == null) throw StateError('Engine gave no playable move: $uci');
      _applyMove(next, _config.engineSide);
    } catch (_) {
      if (isCurrent()) state = state.copyWith(engineThinking: false, engineError: true);
    } finally {
      indicator.cancel();
    }
  }
}

/// Every legal move in UCI notation (promotions to a queen).
List<String> _legalMoves(Position position) => [
  for (final MapEntry(key: from, value: targets) in position.legalMoves.entries)
    for (final to in targets.squares)
      NormalMove(
        from: from,
        to: to,
        promotion:
            position.board.pieceAt(from)?.role == Role.pawn &&
                (to.rank == Rank.first || to.rank == Rank.eighth)
            ? Role.queen
            : null,
      ).uci,
];

/// A nudge that names the piece but lets the arrow show the square.
String hintText(Position position, NormalMove move) {
  final piece = position.board.pieceAt(move.from);
  if (piece == null) return 'Look for the best move.';
  final isCastling = piece.role == Role.king && (move.from.file - move.to.file).abs() > 1;
  if (isCastling) return 'Consider castling.';
  final name = switch (piece.role) {
    Role.pawn => 'pawn',
    Role.knight => 'knight',
    Role.bishop => 'bishop',
    Role.rook => 'rook',
    Role.queen => 'queen',
    Role.king => 'king',
  };
  return 'Look at your $name on ${move.from.name}.';
}
