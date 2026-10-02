// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/game_repository.dart';
import '../../review/domain/move_review.dart';
import '../../play/widgets/result_copy.dart' show moveNumber;
import 'player_stats.dart';

/// Mistakes and blunders in a stretch of moves.
@immutable
class MoveBucket {
  const MoveBucket(this.label, {this.mistakes = 0, this.blunders = 0});

  /// `1–10`, or `41+` for the last.
  final String label;
  final int mistakes;
  final int blunders;

  int get errors => mistakes + blunders;
}

/// The player's mistakes and blunders in reviewed games, by move number in
/// tens: when in a game things go wrong.
List<MoveBucket> errorsByMoveNumber(List<StatsGame> games, {int buckets = 5}) {
  final mistakes = List.filled(buckets, 0);
  final blunders = List.filled(buckets, 0);
  for (final g in games) {
    final analysis = g.analysis;
    if (analysis == null) continue;
    for (final m in analysis.moves) {
      if (m.side != g.record.playerSide) continue;
      final isBlunder = m.quality == MoveQuality.blunder;
      if (!isBlunder && m.quality != MoveQuality.mistake) continue;
      final bucket = ((moveNumber(analysis.game, m.index) - 1) ~/ 10).clamp(0, buckets - 1);
      isBlunder ? blunders[bucket]++ : mistakes[bucket]++;
    }
  }
  return [
    for (var i = 0; i < buckets; i++)
      MoveBucket(
        i == buckets - 1 ? '${i * 10 + 1}+' : '${i * 10 + 1}–${i * 10 + 10}',
        mistakes: mistakes[i],
        blunders: blunders[i],
      ),
  ];
}

/// A game worth remembering, and where to open it.
@immutable
class Best {
  const Best(this.game, this.value, {this.ply});

  final StatsGame game;

  /// Accuracy %, pawns down, or rating: see the field it's in.
  final num value;

  /// The move to open the review at; the end if null.
  final int? ply;
}

/// The player's best moments across every game (not just the period).
@immutable
class PersonalBests {
  const PersonalBests({
    this.bestAccuracy,
    this.biggestComeback,
    this.peakRating,
    this.longestWinStreak = 0,
  });

  factory PersonalBests.of(List<StatsGame> games) {
    Best? accuracy;
    Best? comeback;
    Best? peak;
    for (final g in games) {
      final side = g.record.playerSide;
      if (g.record.playerRating case final rating? when rating > (peak?.value ?? 0)) {
        peak = Best(g, rating);
      }
      final analysis = g.analysis;
      if (analysis == null) continue;
      final ownMoves = analysis.moves.where((m) => m.side == side).length;
      if (analysis.accuracy(side) case final a?
          when ownMoves >= minAccuracyMoves && a > (accuracy?.value ?? 0)) {
        accuracy = Best(g, a);
      }
      if (g.record.outcome != PlayerOutcome.win) continue;
      // The lowest point the player came back from.
      var low = 0.0;
      int? lowPly;
      for (var ply = 0; ply < analysis.evals.length; ply++) {
        final white = analysis.whiteEval(ply);
        if (white == null) continue;
        final own = side == Side.white ? white : -white;
        if (own < low) (low, lowPly) = (own, ply);
      }
      if (low <= -comebackFrom && -low > (comeback?.value ?? 0)) {
        comeback = Best(g, -low, ply: lowPly);
      }
    }

    // Games come newest first; streaks run oldest to newest.
    var longest = 0;
    var run = 0;
    for (final g in games.reversed) {
      run = g.record.outcome == PlayerOutcome.win ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    return PersonalBests(
      bestAccuracy: accuracy,
      biggestComeback: comeback,
      peakRating: peak,
      longestWinStreak: longest,
    );
  }

  /// A short game (a quick resignation) says little about accuracy.
  static const minAccuracyMoves = 10;

  /// Down by this many pawns and still won: a comeback.
  static const comebackFrom = 3.0;

  final Best? bestAccuracy;

  /// Pawns down at the lowest point of a game the player won.
  final Best? biggestComeback;
  final Best? peakRating;
  final int longestWinStreak;

  bool get isEmpty =>
      bestAccuracy == null && biggestComeback == null && peakRating == null && longestWinStreak < 2;
}

/// A number now and before, for the summary's arrows.
@immutable
class Trend {
  const Trend(this.now, this.before);

  final double? now;
  final double? before;

  double? get change => now == null || before == null ? null : now! - before!;
}

/// Win rate (0–100) of [stats], or null without games.
double? winRate(PlayerStats stats) => stats.games == 0 ? null : stats.wins / stats.games * 100;
