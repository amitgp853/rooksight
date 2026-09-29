import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/game_repository.dart';
import '../../review/domain/moment_facts.dart';
import '../../review/domain/move_review.dart';
import 'player_stats.dart';

enum WeaknessKind {
  hangingPieces,
  walkingIntoMate,
  slippedWins,
  missedChances,
  phaseBlunders,
  losingOpening,
  timeLosses,
}

/// A pattern in the player's games, with the games that show it.
@immutable
class Weakness {
  const Weakness({
    required this.kind,
    required this.title,
    required this.detail,
    required this.games,
    required this.considered,
    required this.question,
  });

  final WeaknessKind kind;

  /// `Leaving pieces undefended`.
  final String title;

  /// One line of evidence: `6 blunders in 4 games lost a piece straight away.`
  final String detail;

  /// The games that show it, each with the move to open its review at (null
  /// for the end of the game).
  final Map<int, int?> games;

  /// How many games the pattern was looked for in (reviewed games for the
  /// patterns that need Stockfish).
  final int considered;

  /// A question for the coach about it.
  final String question;

  /// The share of [considered] games it shows up in: the card's meter.
  double get share => considered == 0 ? 0 : games.length / considered;
}

/// A pattern needs at least this many games, so one bad game isn't a habit.
const minWeaknessGames = 2;

/// The player's weaknesses in [games], most widespread first. Computed from
/// Stockfish's analyses and the results alone.
List<Weakness> findWeaknesses(List<StatsGame> games) {
  final reviewed = games.where((g) => g.analysis != null).toList();
  final found = <Weakness>[
    ?_hangingPieces(reviewed),
    ?_walkingIntoMate(reviewed),
    ?_slippedWins(reviewed),
    ?_missedChances(reviewed),
    ?_phaseBlunders(reviewed),
    ?_losingOpening(games),
    ?_timeLosses(games),
  ].where((w) => w.games.length >= minWeaknessGames).toList();
  found.sort((a, b) {
    final byShare = b.share.compareTo(a.share);
    return byShare != 0 ? byShare : a.kind.index.compareTo(b.kind.index);
  });
  return found;
}

/// Phase names for the screen: the review decides phases by what's left on
/// the board, not by move number.
const phaseLabels = {
  'opening': (name: 'Opening', hint: 'first moves'),
  'middlegame': (name: 'Middlegame', hint: 'most pieces on'),
  'endgame': (name: 'Endgame', hint: 'few pieces left'),
};

/// The player's blunders in [g], in game order.
Iterable<MoveReview> _blunders(StatsGame g) => g.analysis!.moves.where(
  (m) => m.side == g.record.playerSide && m.quality == MoveQuality.blunder,
);

/// Blunders after which Stockfish's reply wins a piece or more at once.
Weakness? _hangingPieces(List<StatsGame> reviewed) {
  final games = <int, int?>{};
  var count = 0;
  for (final g in reviewed) {
    for (final m in _blunders(g)) {
      final facts = factsFor(g.analysis!, m, player: g.record.playerSide);
      if (facts.mateAllowed != null || facts.materialAfterReplyLine > -3) continue;
      count++;
      games.putIfAbsent(g.saved.id, () => m.index);
    }
  }
  return Weakness(
    kind: WeaknessKind.hangingPieces,
    title: 'Leaving pieces undefended',
    detail:
        '${_n(count, 'blunder')} in ${_n(games.length, 'game')} lost a piece or more '
        'straight away.',
    games: games,
    considered: reviewed.length,
    question: 'How do I stop leaving pieces undefended?',
  );
}

/// Blunders that allowed a forced mate.
Weakness? _walkingIntoMate(List<StatsGame> reviewed) {
  final games = <int, int?>{};
  for (final g in reviewed) {
    for (final m in _blunders(g)) {
      final after = g.analysis!.evals[m.index + 1].score.mate;
      // Scores after the move are from the opponent's side.
      if (after != null && after > 0) games.putIfAbsent(g.saved.id, () => m.index);
    }
  }
  return Weakness(
    kind: WeaknessKind.walkingIntoMate,
    title: 'Missing threats to your king',
    detail: 'In ${_n(games.length, 'game')}, a move of yours allowed a forced mate.',
    games: games,
    considered: reviewed.length,
    question: 'How do I spot threats against my king in time?',
  );
}

/// Games lost or drawn after being [PlayerStats.winning] or better. Opens
/// at the costliest move after that.
Weakness? _slippedWins(List<StatsGame> reviewed) {
  final games = <int, int?>{};
  for (final g in reviewed) {
    final outcome = g.record.outcome;
    if (outcome != PlayerOutcome.loss && outcome != PlayerOutcome.draw) continue;
    final side = g.record.playerSide;
    if (!PlayerStats.wasWinning(g.analysis!, side)) continue;
    final own = g.analysis!.moves.where((m) => m.side == side);
    games[g.saved.id] = own.isEmpty ? null : own.reduce((a, b) => b.loss > a.loss ? b : a).index;
  }
  return Weakness(
    kind: WeaknessKind.slippedWins,
    title: 'Letting winning positions slip',
    detail:
        'You were ${PlayerStats.winning.round()}+ pawns up in '
        '${_n(games.length, 'game')} you didn’t win.',
    games: games,
    considered: reviewed.length,
    question: 'Why do I let winning positions slip?',
  );
}

/// Opponent blunders the player gave back: their reply lost at least half
/// of what the blunder handed them (and at least a pawn).
Weakness? _missedChances(List<StatsGame> reviewed) {
  final games = <int, int?>{};
  var chances = 0;
  var missed = 0;
  for (final g in reviewed) {
    final moves = g.analysis!.moves;
    for (final m in moves) {
      if (m.side == g.record.playerSide || m.quality != MoveQuality.blunder) continue;
      if (m.index + 1 >= moves.length) continue;
      chances++;
      final reply = moves[m.index + 1];
      if (reply.loss >= 1 && reply.loss >= m.loss / 2) {
        missed++;
        games.putIfAbsent(g.saved.id, () => reply.index);
      }
    }
  }
  return Weakness(
    kind: WeaknessKind.missedChances,
    title: 'Missing your opponents’ mistakes',
    detail: 'You let $missed of their $chances blunders go unpunished.',
    games: games,
    considered: reviewed.length,
    question: 'How do I punish my opponents’ mistakes?',
  );
}

/// One phase with at least half of the blunders (and at least 3 of them).
Weakness? _phaseBlunders(List<StatsGame> reviewed) {
  final byPhase = <String, Map<int, int?>>{};
  final counts = <String, int>{};
  var total = 0;
  for (final g in reviewed) {
    for (final m in _blunders(g)) {
      final phase = gamePhase(g.analysis!.game.history[m.index]);
      total++;
      counts[phase] = (counts[phase] ?? 0) + 1;
      (byPhase[phase] ??= {}).putIfAbsent(g.saved.id, () => m.index);
    }
  }
  if (total == 0) return null;
  final worst = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (worst.value < 3 || worst.value * 2 < total) return null;
  final phase = phaseLabels[worst.key]!.name.toLowerCase();
  return Weakness(
    kind: WeaknessKind.phaseBlunders,
    title: 'Blunders in the $phase',
    detail: '${worst.value} of your $total blunders came in the $phase.',
    games: byPhase[worst.key]!,
    considered: reviewed.length,
    question: 'Why do I blunder so much in the $phase?',
  );
}

/// The worst-scoring opening played at least 3 times, under 40%.
Weakness? _losingOpening(List<StatsGame> games) {
  final stats = PlayerStats.of(games);
  final weak = stats.byOpening.where((o) => o.games >= 3 && o.score < 0.4).toList()
    ..sort((a, b) => a.score.compareTo(b.score));
  if (weak.isEmpty) return null;
  final opening = weak.first;
  final side = opening.side == Side.white ? 'White' : 'Black';
  // Games without an opening name are named by their first moves.
  final named = !opening.name.startsWith(RegExp(r'\d'));
  final lost = {
    for (final g in games)
      if (g.record.playerSide == opening.side &&
          g.record.outcome == PlayerOutcome.loss &&
          openingName(g.record, g.game) == opening.name)
        g.saved.id: null,
  };
  return Weakness(
    kind: WeaknessKind.losingOpening,
    title: named ? 'The ${opening.name} as $side' : 'Games starting ${opening.name} as $side',
    detail: 'You scored ${(opening.score * 100).round()}% over ${opening.games} games.',
    games: lost,
    considered: stats.games,
    question: named
        ? 'How should I play the ${opening.name} as $side?'
        : 'How should I play after ${opening.name} as $side?',
  );
}

/// Losses on time.
Weakness? _timeLosses(List<StatsGame> games) {
  final losses = games.where((g) => g.record.outcome == PlayerOutcome.loss).toList();
  final onTime = {
    for (final g in losses)
      if (g.record.endReason == 'timeout') g.saved.id: null,
  };
  return Weakness(
    kind: WeaknessKind.timeLosses,
    title: 'Losing on time',
    detail: '${onTime.length} of your ${_n(losses.length, 'loss', 'losses')} were on time.',
    games: onTime,
    considered: games.length,
    question: 'How do I stop losing on time?',
  );
}

String _n(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
