import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../../engine/elo_levels.dart';

/// A clock setting from Play setup: base time plus increment per move.
@immutable
class TimeControl {
  const TimeControl._(this.minutes, this.incrementSeconds, this.kind);

  static const none = TimeControl._(0, 0, 'No clock');

  static const options = [
    TimeControl._(3, 2, 'Blitz'),
    TimeControl._(5, 0, 'Blitz'),
    TimeControl._(10, 0, 'Rapid'),
    TimeControl._(15, 10, 'Rapid'),
    TimeControl._(30, 0, 'Classical'),
    none,
  ];

  final int minutes;
  final int incrementSeconds;

  /// Blitz, Rapid, Classical or No clock.
  final String kind;

  bool get hasClock => minutes > 0;

  Duration get initial => Duration(minutes: minutes);

  Duration get increment => Duration(seconds: incrementSeconds);

  /// `10+0`, or `—` without a clock.
  String get label => hasClock ? '$minutes+$incrementSeconds' : '—';

  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      other.minutes == minutes &&
      other.incrementSeconds == incrementSeconds;

  @override
  int get hashCode => Object.hash(minutes, incrementSeconds);
}

/// Colour choice in Play setup.
enum ColourChoice {
  white,
  random,
  black;

  Side resolve(Random random) => switch (this) {
    ColourChoice.white => Side.white,
    ColourChoice.black => Side.black,
    ColourChoice.random => random.nextBool() ? Side.white : Side.black,
  };
}

/// Settings for one game against Stockfish.
@immutable
class GameConfig {
  const GameConfig({
    required this.level,
    required this.playerSide,
    required this.timeControl,
    this.practice = false,
    this.startPosition = Chess.initial,
  });

  static final initial = GameConfig(
    level: EloLevel.of(1600),
    playerSide: Side.white,
    timeControl: TimeControl.options[2],
  );

  final EloLevel level;
  final Side playerSide;
  final TimeControl timeControl;

  /// Practice mode allows taking moves back.
  final bool practice;

  /// Where the game starts (the standard position unless set).
  final Position startPosition;

  Side get engineSide => playerSide.opposite;

  GameConfig copyWith({
    EloLevel? level,
    Side? playerSide,
    TimeControl? timeControl,
    bool? practice,
    Position? startPosition,
  }) {
    return GameConfig(
      level: level ?? this.level,
      playerSide: playerSide ?? this.playerSide,
      timeControl: timeControl ?? this.timeControl,
      practice: practice ?? this.practice,
      startPosition: startPosition ?? this.startPosition,
    );
  }
}

/// The settings the next game starts with. Play setup writes it; the game
/// reads it when it starts. Level, colour and clock are remembered between
/// launches (practice mode and start position are per game).
final gameConfigProvider = NotifierProvider<GameConfigNotifier, GameConfig>(GameConfigNotifier.new);

class GameConfigNotifier extends Notifier<GameConfig> {
  static const _eloKey = 'setup.elo';
  static const _sideKey = 'setup.side';
  static const _clockKey = 'setup.timeControl';

  @override
  GameConfig build() {
    final store = ref.watch(settingsStoreProvider);
    final initial = GameConfig.initial;
    final elo = int.tryParse(store.get(_eloKey) ?? '');
    final side = Side.values.where((s) => s.name == store.get(_sideKey)).firstOrNull;
    final clock = TimeControl.options.where((t) => t.label == store.get(_clockKey)).firstOrNull;
    return initial.copyWith(
      level: elo == null ? null : EloLevel.of(elo),
      playerSide: side,
      timeControl: clock,
    );
  }

  void set(GameConfig config) {
    state = config;
    ref.read(settingsStoreProvider)
      ..set(_eloKey, '${config.level.elo}')
      ..set(_sideKey, config.playerSide.name)
      ..set(_clockKey, config.timeControl.label);
  }
}
