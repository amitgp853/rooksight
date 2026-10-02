// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/analysis_repository.dart';
import '../../../core/storage/game_repository.dart';
import '../../play/domain/game_state.dart';
import '../../play/domain/pgn_import.dart';
import '../../review/domain/game_analysis.dart';
import '../../review/domain/moment_facts.dart' show gamePhase;
import '../../review/domain/move_review.dart';
import '../../review/domain/position_eval.dart';

/// A game for the stats: the saved game, and its analysis once reviewed.
@immutable
class StatsGame {
  const StatsGame(this.saved, this.game, [this.analysis]);

  final SavedGame saved;
  final GameState game;

  /// Present only when Stockfish has analysed the whole game.
  final GameAnalysis? analysis;

  GameRecord get record => saved.record;
}

/// Wins, draws and losses in one opening, played as [side].
@immutable
class OpeningResults {
  const OpeningResults(this.name, this.side, {this.wins = 0, this.draws = 0, this.losses = 0});

  final String name;
  final Side side;
  final int wins;
  final int draws;
  final int losses;

  int get games => wins + draws + losses;

  /// Points scored, as a share of the games: (wins + ½ draws) / games.
  double get score => games == 0 ? 0 : (wins + draws / 2) / games;

  OpeningResults add(PlayerOutcome outcome) => OpeningResults(
    name,
    side,
    wins: wins + (outcome == PlayerOutcome.win ? 1 : 0),
    draws: draws + (outcome == PlayerOutcome.draw ? 1 : 0),
    losses: losses + (outcome == PlayerOutcome.loss ? 1 : 0),
  );
}

/// One of the player's errors, with the game it came from.
@immutable
class StatsMoment {
  const StatsMoment(this.game, this.moment);

  final StatsGame game;
  final MoveReview moment;
}

/// The player's results and habits across their games, all computed on the
/// phone. Error counts come from reviewed games only.
@immutable
class PlayerStats {
  const PlayerStats({
    required this.games,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.byOpening,
    required this.reviewed,
    required this.averageAccuracy,
    required this.mistakes,
    required this.blunders,
    required this.errorsByPhase,
    required this.lossesFromWinning,
    required this.worst,
  });

  factory PlayerStats.of(List<StatsGame> games) {
    var wins = 0, draws = 0, losses = 0;
    final openings = <(String, Side), OpeningResults>{};
    for (final g in games) {
      final outcome = g.record.outcome;
      switch (outcome) {
        case PlayerOutcome.win:
          wins++;
        case PlayerOutcome.draw:
          draws++;
        case PlayerOutcome.loss:
          losses++;
        case PlayerOutcome.unknown:
          continue;
      }
      final key = (openingName(g.record, g.game), g.record.playerSide);
      openings[key] = (openings[key] ?? OpeningResults(key.$1, key.$2)).add(outcome);
    }

    final reviewed = games.where((g) => g.analysis != null).toList();
    final accuracies = <double>[];
    final errors = <StatsMoment>[];
    final byPhase = {for (final phase in phases) phase: (mistakes: 0, blunders: 0)};
    var lossesFromWinning = 0;
    for (final g in reviewed) {
      final analysis = g.analysis!;
      final side = g.record.playerSide;
      if (analysis.accuracy(side) case final accuracy?) accuracies.add(accuracy);
      for (final m in analysis.moves) {
        if (m.side != side) continue;
        final isBlunder = m.quality == MoveQuality.blunder;
        if (!isBlunder && m.quality != MoveQuality.mistake) continue;
        errors.add(StatsMoment(g, m));
        final phase = gamePhase(analysis.game.history[m.index]);
        final counts = byPhase[phase]!;
        byPhase[phase] = isBlunder
            ? (mistakes: counts.mistakes, blunders: counts.blunders + 1)
            : (mistakes: counts.mistakes + 1, blunders: counts.blunders);
      }
      if (g.record.outcome == PlayerOutcome.loss && wasWinning(analysis, side)) {
        lossesFromWinning++;
      }
    }

    return PlayerStats(
      games: wins + draws + losses,
      wins: wins,
      draws: draws,
      losses: losses,
      byOpening: openings.values.toList()..sort((a, b) => b.games.compareTo(a.games)),
      reviewed: reviewed.length,
      averageAccuracy: accuracies.isEmpty
          ? null
          : accuracies.reduce((a, b) => a + b) / accuracies.length,
      mistakes: errors.where((e) => e.moment.quality == MoveQuality.mistake).length,
      blunders: errors.where((e) => e.moment.quality == MoveQuality.blunder).length,
      errorsByPhase: byPhase,
      lossesFromWinning: lossesFromWinning,
      worst: (errors..sort((a, b) => b.moment.loss.compareTo(a.moment.loss))).take(3).toList(),
    );
  }

  static const phases = ['opening', 'middlegame', 'endgame'];

  /// Ahead by this many pawns counts as a winning position.
  static const winning = 2.0;

  /// Finished games with a known result.
  final int games;
  final int wins;
  final int draws;
  final int losses;

  /// By opening and colour, most played first.
  final List<OpeningResults> byOpening;

  /// Games Stockfish has fully analysed.
  final int reviewed;
  final double? averageAccuracy;

  /// The player's mistakes and blunders in reviewed games.
  final int mistakes;
  final int blunders;

  /// Mistakes and blunders by game phase ([phases]).
  final Map<String, ({int mistakes, int blunders})> errorsByPhase;

  /// Reviewed games lost after being [winning] or better.
  final int lossesFromWinning;

  /// The player's three costliest errors.
  final List<StatsMoment> worst;

  double? get blundersPerGame => reviewed == 0 ? null : blunders / reviewed;
  double? get mistakesPerGame => reviewed == 0 ? null : mistakes / reviewed;

  /// Whether [side] stood [winning] or better at any point.
  static bool wasWinning(GameAnalysis analysis, Side side) {
    for (var ply = 0; ply < analysis.evals.length; ply++) {
      final white = analysis.whiteEval(ply);
      if (white == null) continue;
      if ((side == Side.white ? white : -white) >= winning) return true;
    }
    return false;
  }
}

/// The opening's family name: from an `Opening` header (Lichess) or
/// Chess.com's `ECOUrl` ("Sicilian Defense"), else the first moves ("1. e4 c5").
String openingName(GameRecord record, GameState game) {
  final headers = PgnGame.parsePgn(record.pgn, initHeaders: PgnGame.emptyHeaders).headers;
  // Lichess names the variation too ("Alekhine Defense: Sämisch Attack"):
  // keep the family, as for Chess.com, so results group by opening.
  final named = headers['Opening']?.split(':').first.trim() ?? _fromEcoUrl(headers['ECOUrl']);
  if (named != null && named.isNotEmpty) return named;
  final sans = game.moves.take(2).map((m) => m.san).toList();
  if (sans.isEmpty) return 'No moves';
  return sans.length == 1 ? '1. ${sans[0]}' : '1. ${sans[0]} ${sans[1]}';
}

/// The opening's name from the PGN, or null when it has none: the first
/// moves [openingName] falls back to aren't a name to give the AI coach.
String? namedOpening(GameRecord record, GameState game) {
  final name = openingName(record, game);
  return name.startsWith('1.') || name == 'No moves' ? null : name;
}

/// `…/openings/Sicilian-Defense-Alapin-Variation-2...Nf6` → `Sicilian Defense`.
String? _fromEcoUrl(String? url) {
  if (url == null) return null;
  final slug = Uri.tryParse(url)?.pathSegments.lastOrNull;
  if (slug == null) return null;
  final words = slug.split('-').takeWhile((w) => !w.contains(RegExp(r'\d'))).toList();
  const family = {'Opening', 'Defense', 'Defence', 'Game', 'Gambit', 'Attack', 'System'};
  final end = words.indexWhere(family.contains);
  final name = end < 0 ? words.take(3) : words.take(end + 1);
  return name.join(' ').replaceAll('Kings', 'King’s').replaceAll('Queens', 'Queen’s');
}

/// The newest [limit] games (all of them if null), with analyses where
/// complete.
Future<List<StatsGame>> loadStatsGames(
  GameRepository games,
  AnalysisRepository analyses, {
  int? limit = 50,
}) async {
  final all = await games.watchAll().first;
  return statsGamesOf(limit == null ? all : all.take(limit), analyses);
}

/// [saved] with their analyses where complete. Games whose PGN can't be
/// read are skipped.
Future<List<StatsGame>> statsGamesOf(Iterable<SavedGame> saved, AnalysisRepository analyses) async {
  final result = <StatsGame>[];
  for (final s in saved) {
    final GameState game;
    try {
      game = gameFromPgn(s.record.pgn);
    } on Object {
      continue;
    }
    final stored = await analyses.analysis(s.id);
    final analysis = stored != null && stored.complete
        ? GameAnalysis(game, stored.evals.map(PositionEval.fromJson).toList())
        : null;
    result.add(StatsGame(s, game, analysis));
  }
  return result;
}
