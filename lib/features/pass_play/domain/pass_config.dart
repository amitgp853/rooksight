// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../play/domain/game_config.dart';

/// Settings for a pass & play game: two people taking turns on one phone.
///
/// The first player is the phone's owner ("You" by default). Their side is
/// the one saved as the player's, so the game counts in their stats.
@immutable
class PassConfig {
  const PassConfig({
    required this.firstName,
    required this.secondName,
    required this.firstSide,
    required this.timeControl,
    this.autoFlip = true,
    this.faceToFace = false,
    this.takebacks = true,
  });

  static const defaultFirstName = 'You';
  static const defaultSecondName = 'Opponent';
  static const maxNameLength = 16;

  static const initial = PassConfig(
    firstName: defaultFirstName,
    secondName: defaultSecondName,
    firstSide: Side.white,
    timeControl: TimeControl.passDefault,
  );

  final String firstName;
  final String secondName;
  final Side firstSide;

  /// Each player's clock.
  final TimeControl timeControl;

  /// Turn the board after each move so the player to move sits at the bottom.
  final bool autoFlip;

  /// The phone lies flat between the players; the top half is turned for the
  /// second player and the board never flips.
  final bool faceToFace;

  /// Players may take back a move, with the other player's consent.
  final bool takebacks;

  Side get secondSide => firstSide.opposite;

  String nameOf(Side side) => side == firstSide ? firstName : secondName;

  /// Same players with colours swapped (a rematch).
  PassConfig get swapped => copyWith(firstSide: firstSide.opposite);

  /// Face-to-face and auto-flip exclude each other: turning one on turns the
  /// other off.
  PassConfig withFaceToFace(bool on) => copyWith(faceToFace: on, autoFlip: on ? false : autoFlip);

  PassConfig withAutoFlip(bool on) => copyWith(autoFlip: on, faceToFace: on ? false : faceToFace);

  PassConfig copyWith({
    String? firstName,
    String? secondName,
    Side? firstSide,
    TimeControl? timeControl,
    bool? autoFlip,
    bool? faceToFace,
    bool? takebacks,
  }) {
    return PassConfig(
      firstName: firstName ?? this.firstName,
      secondName: secondName ?? this.secondName,
      firstSide: firstSide ?? this.firstSide,
      timeControl: timeControl ?? this.timeControl,
      autoFlip: autoFlip ?? this.autoFlip,
      faceToFace: faceToFace ?? this.faceToFace,
      takebacks: takebacks ?? this.takebacks,
    );
  }

  /// A typed name, trimmed and capped at [maxNameLength]; [fallback] if blank.
  static String cleanName(String name, String fallback) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength) : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is PassConfig &&
      other.firstName == firstName &&
      other.secondName == secondName &&
      other.firstSide == firstSide &&
      other.timeControl == timeControl &&
      other.autoFlip == autoFlip &&
      other.faceToFace == faceToFace &&
      other.takebacks == takebacks;

  @override
  int get hashCode =>
      Object.hash(firstName, secondName, firstSide, timeControl, autoFlip, faceToFace, takebacks);
}

/// The settings the next pass & play game starts with, remembered between
/// launches. Pass setup writes it; the game reads it when it starts.
final passConfigProvider = NotifierProvider<PassConfigNotifier, PassConfig>(PassConfigNotifier.new);

class PassConfigNotifier extends Notifier<PassConfig> {
  static const _firstNameKey = 'pass.firstName';
  static const _secondNameKey = 'pass.secondName';
  static const _firstSideKey = 'pass.firstSide';
  static const _clockKey = 'pass.timeControl';
  static const _autoFlipKey = 'pass.autoFlip';
  static const _faceToFaceKey = 'pass.faceToFace';
  static const _takebacksKey = 'pass.takebacks';

  @override
  PassConfig build() {
    final store = ref.watch(settingsStoreProvider);
    bool? flag(String key) => switch (store.get(key)) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    final initial = PassConfig.initial;
    return initial.copyWith(
      firstName: store.get(_firstNameKey),
      secondName: store.get(_secondNameKey),
      firstSide: Side.values.where((s) => s.name == store.get(_firstSideKey)).firstOrNull,
      timeControl: TimeControl.passOptions
          .where((t) => t.label == store.get(_clockKey))
          .firstOrNull,
      autoFlip: flag(_autoFlipKey),
      faceToFace: flag(_faceToFaceKey),
      takebacks: flag(_takebacksKey),
    );
  }

  void set(PassConfig config) {
    state = config;
    ref.read(settingsStoreProvider)
      ..set(_firstNameKey, config.firstName)
      ..set(_secondNameKey, config.secondName)
      ..set(_firstSideKey, config.firstSide.name)
      ..set(_clockKey, config.timeControl.label)
      ..set(_autoFlipKey, '${config.autoFlip}')
      ..set(_faceToFaceKey, '${config.faceToFace}')
      ..set(_takebacksKey, '${config.takebacks}');
  }
}
