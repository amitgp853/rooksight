// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/display_settings.dart';
import '../../core/storage/analysis_repository.dart';
import '../../engine/engine_provider.dart';
import '../games/games_screen.dart' show opponentName;
import '../review/domain/game_analyzer.dart';
import '../review/domain/position_eval.dart';
import 'domain/player_stats.dart';

/// Where a bulk review stands.
@immutable
class BulkReviewState {
  const BulkReviewState({
    this.running = false,
    this.total = 0,
    this.finished = 0,
    this.current,
    this.progress = 0,
  });

  final bool running;

  /// Games in this run, and how many are done.
  final int total;
  final int finished;

  /// The game being analysed, e.g. `vs sayles0`.
  final String? current;

  /// How far into [current], 0–1.
  final double progress;
}

/// Reviews many games with Stockfish, one after another, while the stats
/// screen is open. Progress is saved as it goes (as in a single review), so
/// a run that stops picks up where it left off. No AI calls.
final bulkReviewProvider = NotifierProvider.autoDispose<BulkReviewController, BulkReviewState>(
  BulkReviewController.new,
);

class BulkReviewController extends Notifier<BulkReviewState> {
  /// Fast is plenty for spotting patterns across games.
  static final depth = AnalysisDepth.fast.plies;

  /// Saved every this many positions.
  static const saveEvery = 10;

  bool _stopped = false;

  @override
  BulkReviewState build() {
    ref.onDispose(() => _stopped = true);
    return const BulkReviewState();
  }

  Future<void> start(List<StatsGame> games) async {
    if (state.running || games.isEmpty) return;
    _stopped = false;
    final repository = ref.read(analysisRepositoryProvider);
    final analyzer = GameAnalyzer(ref.read(chessEngineProvider));
    state = BulkReviewState(running: true, total: games.length);

    for (final (i, g) in games.indexed) {
      if (_stopped) break;
      state = BulkReviewState(
        running: true,
        total: games.length,
        finished: i,
        current: 'vs ${opponentName(g.record)}',
      );
      try {
        await _review(g, repository, analyzer, (progress) {
          if (_stopped) return;
          state = BulkReviewState(
            running: true,
            total: games.length,
            finished: i,
            current: state.current,
            progress: progress,
          );
        });
      } on Object catch (error) {
        // One game that can't be analysed shouldn't stop the rest.
        debugPrint('Bulk review of game ${g.saved.id} failed: $error');
      }
    }
    if (!_stopped) {
      state = BulkReviewState(total: games.length, finished: games.length);
    }
  }

  /// Stops after the current position; what's done is kept.
  void stop() {
    _stopped = true;
    state = BulkReviewState(total: state.total, finished: state.finished);
  }

  Future<void> _review(
    StatsGame g,
    AnalysisRepository repository,
    GameAnalyzer analyzer,
    void Function(double) onProgress,
  ) async {
    final id = g.saved.id;
    final stored = await repository.analysis(id);
    if (stored?.complete ?? false) return;
    // A partial analysis continues at its own depth.
    final depthUsed = stored?.depth ?? depth;
    var evals = [...?stored?.evals.map(PositionEval.fromJson)];
    final positions = g.game.history.length;

    Future<void> save({required bool complete}) => repository.saveAnalysis(
      id,
      StoredAnalysis(
        depth: depthUsed,
        evals: [for (final e in evals) e.toJson()],
        complete: complete,
      ),
    );

    await for (final next in analyzer.analyze(
      g.game,
      depth: depthUsed,
      done: evals,
      isCancelled: () => _stopped,
    )) {
      evals = next;
      onProgress(evals.length / positions);
      if (evals.length % saveEvery == 0) await save(complete: false);
    }
    await save(complete: evals.length == positions);
  }
}
