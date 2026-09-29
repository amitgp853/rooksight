import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/feedback/sound_player.dart';
import 'game_state.dart';

/// The sound and haptic for a move that has just been played.
@immutable
class MoveFeedback {
  const MoveFeedback(this.sound, this.haptic);

  /// Picks the feedback for [move], per the motion spec: one sound (check
  /// over castle over capture over move) and one haptic (game over and
  /// captures are medium, a check on the player's king is heavy, anything
  /// else light).
  factory MoveFeedback.of(PlayedMove move, {required Side playerSide, required bool gameOver}) {
    final isCheck = move.san.endsWith('+') || move.san.endsWith('#');
    final isCastle = move.san.startsWith('O-O');
    final isCapture = move.captured != null;

    final sound = isCheck
        ? GameSound.check
        : isCastle
        ? GameSound.castle
        : isCapture
        ? GameSound.capture
        : GameSound.move;
    final haptic = gameOver || isCapture
        ? Haptic.medium
        : isCheck && move.side != playerSide
        ? Haptic.heavy
        : Haptic.light;
    return MoveFeedback(sound, haptic);
  }

  final GameSound sound;
  final Haptic haptic;

  @override
  bool operator ==(Object other) =>
      other is MoveFeedback && other.sound == sound && other.haptic == haptic;

  @override
  int get hashCode => Object.hash(sound, haptic);

  @override
  String toString() => 'MoveFeedback(${sound.name}, ${haptic.name})';
}
