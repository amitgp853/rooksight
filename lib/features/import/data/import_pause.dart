// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play/domain/game_controller.dart' show nowProvider;

/// The wait after a site asks us to slow down (HTTP 429), made visible:
/// when it ends, for the import screen's countdown, and a way to end it
/// early ("Try now"). Null while not waiting.
final importPauseProvider = NotifierProvider<ImportPause, DateTime?>(ImportPause.new);

class ImportPause extends Notifier<DateTime?> {
  Completer<void>? _skip;

  @override
  DateTime? build() => null;

  /// Waits [duration], or until [skip]. The APIs call this between retries.
  Future<void> wait(Duration duration) async {
    final skip = _skip = Completer<void>();
    state = ref.read(nowProvider)().add(duration);
    try {
      await Future.any([Future<void>.delayed(duration), skip.future]);
    } finally {
      if (identical(_skip, skip)) {
        _skip = null;
        state = null;
      }
    }
  }

  /// Ends the current wait now.
  void skip() {
    final skip = _skip;
    if (skip != null && !skip.isCompleted) skip.complete();
  }
}
