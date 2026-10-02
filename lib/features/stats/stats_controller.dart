// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/analysis_repository.dart';
import '../games/games_screen.dart' show savedGamesProvider;
import 'domain/insights.dart';
import 'domain/player_stats.dart';
import 'domain/weaknesses.dart';

/// How many recent games the stats cover.
enum StatsPeriod {
  last20(20, 'Last 20'),
  last50(50, 'Last 50'),
  all(null, 'All time');

  const StatsPeriod(this.limit, this.label);

  /// Null for every game.
  final int? limit;
  final String label;
}

final statsPeriodProvider = NotifierProvider<StatsPeriodSetting, StatsPeriod>(
  StatsPeriodSetting.new,
);

class StatsPeriodSetting extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.last20;

  void select(StatsPeriod period) => state = period;
}

/// Everything the stats screen shows, for the chosen period.
@immutable
class StatsView {
  StatsView({required this.games, required this.previous, required this.all})
    : stats = PlayerStats.of(games),
      previousStats = previous.length < minPrevious ? null : PlayerStats.of(previous),
      weaknesses = findWeaknesses(games),
      bests = PersonalBests.of(all);

  /// The period's games, newest first.
  final List<StatsGame> games;

  /// The same number of games before them, for the trends (empty for "All
  /// time", or when there aren't that many games).
  final List<StatsGame> previous;

  /// Fewer earlier games than this make no fair comparison.
  static const minPrevious = 5;

  /// Every game, for personal bests.
  final List<StatsGame> all;

  final PlayerStats stats;
  final PlayerStats? previousStats;

  /// Most widespread first.
  final List<Weakness> weaknesses;
  final PersonalBests bests;

  /// Games Stockfish hasn't fully analysed yet.
  List<StatsGame> get unreviewed => games.where((g) => g.analysis == null).toList();
}

/// The stats for the chosen period; updates as games are added.
final statsViewProvider = FutureProvider.autoDispose<StatsView>((ref) async {
  final saved = await ref.watch(savedGamesProvider.future);
  final limit = ref.watch(statsPeriodProvider).limit;
  final all = await statsGamesOf(saved, ref.watch(analysisRepositoryProvider));
  if (limit == null) return StatsView(games: all, previous: const [], all: all);
  return StatsView(
    games: all.take(limit).toList(),
    previous: all.skip(limit).take(limit).toList(),
    all: all,
  );
});
