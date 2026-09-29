import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../play/domain/game_clock.dart';
import '../../play/domain/game_config.dart';
import '../../play/domain/game_state.dart';
import '../../play/domain/unfinished_game.dart' show ResumeRequest;
import 'pass_config.dart';
import 'pass_session.dart';

/// A pass & play game that isn't over yet ("Save and finish later"), kept so
/// it can be resumed from Home, even after the app closes. The clocks are
/// stored stopped.
@immutable
class UnfinishedPassGame {
  const UnfinishedPassGame({
    required this.config,
    required this.moves,
    required this.clockTimes,
    required this.startedAt,
    required this.savedAt,
    this.white,
    this.black,
  });

  /// [session] as it stands at [now], or null when there's nothing to resume
  /// (no move yet, or the game is over).
  static UnfinishedPassGame? of(PassSession session, DateTime now) {
    final game = session.game;
    if (game.isOver || game.moves.isEmpty) return null;
    final clock = session.clock?.stop(now);
    return UnfinishedPassGame(
      config: session.config,
      moves: [for (final m in game.moves) m.move.uci],
      clockTimes: session.clockTimes,
      startedAt: session.startedAt ?? now,
      savedAt: now,
      white: clock?.white,
      black: clock?.black,
    );
  }

  final PassConfig config;

  /// The moves so far, in UCI.
  final List<String> moves;
  final List<Duration> clockTimes;
  final DateTime startedAt;

  /// When it was last saved, to pick the most recent game on Home.
  final DateTime savedAt;

  /// Time left on each clock; null without a clock.
  final Duration? white;
  final Duration? black;

  /// The game replayed from its moves.
  GameState get game {
    var state = GameState.start();
    for (final uci in moves) {
      final move = Move.parse(uci);
      final next = move == null ? null : state.play(move);
      if (next == null) break;
      state = next;
    }
    return state;
  }

  /// The session to continue. It opens paused, so nobody's clock runs until
  /// the players are ready.
  PassSession resume() {
    final timeControl = config.timeControl;
    return PassSession(
      config: config,
      game: game,
      clock: timeControl.hasClock && white != null && black != null
          ? GameClock.stopped(white: white!, black: black!, increment: timeControl.increment)
          : null,
      clockTimes: clockTimes,
      paused: true,
      startedAt: startedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'first': config.firstName,
    'second': config.secondName,
    'firstSide': config.firstSide.name,
    'clock': config.timeControl.label,
    'autoFlip': config.autoFlip,
    'faceToFace': config.faceToFace,
    'takebacks': config.takebacks,
    'moves': moves,
    'clockTimes': [for (final t in clockTimes) t.inMilliseconds],
    'startedAt': startedAt.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
    'white': ?white?.inMilliseconds,
    'black': ?black?.inMilliseconds,
  };

  /// Null if [json] can't be read (an older or damaged save).
  static UnfinishedPassGame? fromJson(Map<String, Object?> json) {
    try {
      return UnfinishedPassGame(
        config: PassConfig(
          firstName: json['first']! as String,
          secondName: json['second']! as String,
          firstSide: Side.values.byName(json['firstSide']! as String),
          timeControl: TimeControl.passOptions.firstWhere((t) => t.label == json['clock']),
          autoFlip: json['autoFlip']! as bool,
          faceToFace: json['faceToFace']! as bool,
          takebacks: json['takebacks']! as bool,
        ),
        moves: (json['moves']! as List<Object?>).cast<String>(),
        clockTimes: [
          for (final ms in (json['clockTimes']! as List<Object?>).cast<int>())
            Duration(milliseconds: ms),
        ],
        startedAt: DateTime.parse(json['startedAt']! as String),
        savedAt: DateTime.parse(json['savedAt']! as String),
        white: _millis(json['white']),
        black: _millis(json['black']),
      );
    } on Object {
      return null;
    }
  }

  static Duration? _millis(Object? value) => value is int ? Duration(milliseconds: value) : null;
}

/// The pass & play game to resume, if any. Kept in the settings store, so it
/// survives the app closing.
final unfinishedPassGameProvider = NotifierProvider<UnfinishedPassGameStore, UnfinishedPassGame?>(
  UnfinishedPassGameStore.new,
);

class UnfinishedPassGameStore extends Notifier<UnfinishedPassGame?> {
  static const _key = 'pass.unfinished';

  @override
  UnfinishedPassGame? build() => load(ref.watch(settingsStoreProvider));

  /// The saved game in [store], freshly read.
  static UnfinishedPassGame? load(SettingsStore store) {
    final stored = store.get(_key);
    if (stored == null || stored.isEmpty) return null;
    try {
      return UnfinishedPassGame.fromJson(jsonDecode(stored) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  /// Writes [session] to [store] (or clears it when there's nothing to
  /// resume) without touching provider state: for a game screen that is
  /// closing, where providers can't be changed.
  static UnfinishedPassGame? write(SettingsStore store, PassSession session, DateTime now) {
    final unfinished = UnfinishedPassGame.of(session, now);
    store.set(_key, unfinished == null ? '' : jsonEncode(unfinished.toJson()));
    return unfinished;
  }

  /// Keeps [session] for later, or forgets it once there's nothing to resume.
  void save(PassSession session, DateTime now) =>
      state = write(ref.read(settingsStoreProvider), session, now);

  void clear() {
    ref.read(settingsStoreProvider).set(_key, '');
    state = null;
  }
}

/// Set by Home's Resume just before opening the pass & play screen.
final resumePassGameProvider = Provider<ResumeRequest>((ref) => ResumeRequest());
