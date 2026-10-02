// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:rooksight/core/feedback/sound_player.dart';

/// Records the sounds a test's game would play.
class FakeSoundPlayer implements SoundPlayer {
  final played = <GameSound>[];

  @override
  void play(GameSound sound) => played.add(sound);
}
