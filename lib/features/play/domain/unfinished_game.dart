import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../../engine/elo_levels.dart';
import 'game_clock.dart';
import 'game_config.dart';
import 'game_session.dart';
import 'game_state.dart';

/// A game against Stockfish that isn't over yet, kept so it can be resumed
/// from Home, even after the app closes. The clocks are stored stopped: time
/// away from the game isn't charged.
@immutable
class UnfinishedGame {
  const UnfinishedGame({
    required this.config,
    required this.moves,
    required this.hintsUsed,
    required this.startedAt,
    this.white,
    this.black,
  });

  /// [session] as it stands at [now], or null when there's nothing to resume
  /// (no move yet, or the game is over).
  static UnfinishedGame? of(GameSession session, DateTime now) {
    final game = session.game;
    if (game.isOver || game.moves.isEmpty) return null;
    final clock = session.clock?.stop(now);
    return UnfinishedGame(
      config: session.config,
      moves: [for (final m in game.moves) m.move.uci],
      hintsUsed: session.hintsUsed,
      startedAt: session.startedAt ?? now,
      white: clock?.white,
      black: clock?.black,
    );
  }

  final GameConfig config;

  /// The moves so far, in UCI.
  final List<String> moves;
  final int hintsUsed;
  final DateTime startedAt;

  /// Time left on each clock; null without a clock.
  final Duration? white;
  final Duration? black;

  /// The game replayed from its moves.
  GameState get game {
    var state = GameState.start(config.startPosition);
    for (final uci in moves) {
      final move = Move.parse(uci);
      final next = move == null ? null : state.play(move);
      if (next == null) break;
      state = next;
    }
    return state;
  }

  /// The session to continue, with the clock of the side to move running
  /// from [now].
  GameSession resume(DateTime now) {
    final game = this.game;
    final timeControl = config.timeControl;
    final clock = timeControl.hasClock && white != null && black != null
        ? GameClock.stopped(
            white: white!,
            black: black!,
            increment: timeControl.increment,
          ).resume(game.turn, now)
        : null;
    return GameSession(
      config: config,
      game: game,
      clock: clock,
      hintsUsed: hintsUsed,
      startedAt: startedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'elo': config.level.elo,
    'side': config.playerSide.name,
    'clock': config.timeControl.label,
    'practice': config.practice,
    'start': config.startPosition.fen,
    'moves': moves,
    'hints': hintsUsed,
    'startedAt': startedAt.toIso8601String(),
    'white': ?white?.inMilliseconds,
    'black': ?black?.inMilliseconds,
  };

  /// Null if [json] can't be read (an older or damaged save).
  static UnfinishedGame? fromJson(Map<String, Object?> json) {
    try {
      final start = json['start']! as String;
      return UnfinishedGame(
        config: GameConfig(
          level: EloLevel.of(json['elo']! as int),
          playerSide: Side.values.byName(json['side']! as String),
          timeControl: TimeControl.options.firstWhere((t) => t.label == json['clock']),
          practice: json['practice']! as bool,
          startPosition: start == Chess.initial.fen
              ? Chess.initial
              : Chess.fromSetup(Setup.parseFen(start)),
        ),
        moves: (json['moves']! as List<Object?>).cast<String>(),
        hintsUsed: json['hints']! as int,
        startedAt: DateTime.parse(json['startedAt']! as String),
        white: _millis(json['white']),
        black: _millis(json['black']),
      );
    } on Object {
      return null;
    }
  }

  static Duration? _millis(Object? value) => value is int ? Duration(milliseconds: value) : null;
}

/// The game to resume, if any. Kept in the settings store, so it survives
/// the app closing.
final unfinishedGameProvider = NotifierProvider<UnfinishedGameStore, UnfinishedGame?>(
  UnfinishedGameStore.new,
);

class UnfinishedGameStore extends Notifier<UnfinishedGame?> {
  static const _key = 'game.unfinished';

  @override
  UnfinishedGame? build() => load(ref.watch(settingsStoreProvider));

  /// The saved game in [store], freshly read.
  static UnfinishedGame? load(SettingsStore store) {
    final stored = store.get(_key);
    if (stored == null || stored.isEmpty) return null;
    try {
      return UnfinishedGame.fromJson(jsonDecode(stored) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  /// Writes [session] to [store] (or clears it when there's nothing to
  /// resume) without touching provider state: for a game screen that is
  /// closing, where providers can't be changed.
  static UnfinishedGame? write(SettingsStore store, GameSession session, DateTime now) {
    final unfinished = UnfinishedGame.of(session, now);
    store.set(_key, unfinished == null ? '' : jsonEncode(unfinished.toJson()));
    return unfinished;
  }

  /// Keeps [session] for later, or forgets it once there's nothing to resume.
  void save(GameSession session, DateTime now) =>
      state = write(ref.read(settingsStoreProvider), session, now);

  void clear() {
    ref.read(settingsStoreProvider).set(_key, '');
    state = null;
  }
}

/// Set by Home's Resume just before opening the game screen: the next game
/// starts from [unfinishedGameProvider] instead of a new board. A plain
/// one-shot flag, not provider state: the game reads and resets it while it
/// builds, where changing another provider isn't allowed.
final resumeGameProvider = Provider<ResumeRequest>((ref) => ResumeRequest());

class ResumeRequest {
  bool _requested = false;

  void request() => _requested = true;

  /// Whether a resume was asked for; resets the request.
  bool take() {
    final requested = _requested;
    _requested = false;
    return requested;
  }
}
