import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/board/landing_square.dart';
import '../../../core/storage/game_repository.dart';
import '../../games/games_screen.dart' show opponentName, timeControlLabel;
import '../../play/widgets/result_copy.dart' show moveLabel;
import '../../review/domain/game_analysis.dart';
import '../../review/domain/move_review.dart';
import '../../review/domain/position_eval.dart';
import '../../stats/domain/player_stats.dart' show openingName;

/// A move shown on the card: the position after it, with its mark.
@immutable
class ReportMove {
  const ReportMove({
    required this.label,
    required this.fen,
    required this.lastMove,
    this.quality,
    this.mark,
  });

  /// `7. Bg5!`.
  final String label;
  final String fen;
  final Move lastMove;
  final MoveQuality? quality;

  /// Where the quality badge goes.
  final Square? mark;
}

/// What the report card shows for one reviewed game.
@immutable
class GameReport {
  const GameReport({
    required this.context,
    required this.accuracy,
    required this.verdict,
    required this.aiVerdict,
    required this.playedAt,
    required this.orientation,
    this.best,
    this.worst,
  });

  /// [aiVerdict] is the AI's one-line verdict, if the game was explained.
  factory GameReport.of(SavedGame saved, GameAnalysis analysis, {String? aiVerdict}) {
    final record = saved.record;
    final side = record.playerSide;
    final own = analysis.moves.where((m) => m.side == side).toList();
    final accuracy = analysis.accuracy(side);
    final blunders = own.where((m) => m.quality == MoveQuality.blunder).length;
    return GameReport(
      context: [
        'vs ${opponentName(record)}',
        ?_timeControl(record),
        openingName(record, analysis.game),
      ].join(' · '),
      accuracy: accuracy,
      verdict: aiVerdict ?? plainVerdict(record.outcome, accuracy, blunders),
      aiVerdict: aiVerdict != null,
      playedAt: record.endedAt,
      orientation: side,
      best: _reportMove(analysis, bestMove(analysis, own)),
      worst: _reportMove(analysis, worstMove(own)),
    );
  }

  /// `vs Stockfish 1600 · Rapid 10+0 · Italian Game`.
  final String context;

  /// The player's accuracy (0–100).
  final double? accuracy;
  final String verdict;

  /// Whether [verdict] is the AI's, or built from the numbers.
  final bool aiVerdict;
  final DateTime playedAt;
  final Side orientation;

  final ReportMove? best;

  /// Null when the player made no mistake or blunder.
  final ReportMove? worst;

  /// The player's best move: a brilliant one, else a "one good move", else
  /// the move where their choice mattered most (the widest gap between
  /// Stockfish's first and second choice among moves that matched the first).
  @visibleForTesting
  static MoveReview? bestMove(GameAnalysis analysis, List<MoveReview> own) {
    MoveReview? widest(Iterable<MoveReview> moves) => moves.isEmpty
        ? null
        : moves.reduce((a, b) => _gap(analysis, b) > _gap(analysis, a) ? b : a);
    return widest(own.where((m) => m.quality == MoveQuality.brilliant)) ??
        widest(own.where((m) => m.quality == MoveQuality.best)) ??
        widest(own.where((m) => m.loss < 0.05 && analysis.evals[m.index].secondScore != null));
  }

  /// The player's costliest blunder, else their worst mistake.
  @visibleForTesting
  static MoveReview? worstMove(List<MoveReview> own) {
    for (final quality in [MoveQuality.blunder, MoveQuality.mistake]) {
      final errors = own.where((m) => m.quality == quality).toList();
      if (errors.isNotEmpty) return errors.reduce((a, b) => b.loss > a.loss ? b : a);
    }
    return null;
  }

  /// How much better Stockfish's first choice was than its second, in pawns.
  static double _gap(GameAnalysis analysis, MoveReview m) {
    final eval = analysis.evals[m.index];
    final second = eval.secondScore;
    if (second == null) return 0;
    return cappedPawns(eval.score) - cappedPawns(second);
  }

  static ReportMove? _reportMove(GameAnalysis analysis, MoveReview? m) {
    if (m == null) return null;
    final game = analysis.game;
    final played = game.moves[m.index];
    return ReportMove(
      label: '${moveLabel(game, m.index)}${m.quality?.symbol ?? ''}',
      fen: game.history[m.index + 1].fen,
      lastMove: played.move,
      quality: m.quality,
      mark: landingSquare(game.history[m.index], played.move),
    );
  }

  /// `Rapid 10+0`, `Daily`, `10+0`, or null.
  static String? _timeControl(GameRecord record) {
    final label = timeControlLabel(record);
    final timeClass = record.timeClass;
    if (timeClass == null || timeClass == 'daily') return label;
    final name = '${timeClass[0].toUpperCase()}${timeClass.substring(1)}';
    return label == null ? name : '$name $label';
  }
}

/// A one-line verdict from the numbers alone, for games the AI hasn't
/// explained.
String plainVerdict(PlayerOutcome outcome, double? accuracy, int blunders) {
  final acc = accuracy == null ? null : '${accuracy.round()}% accuracy';
  final noun = blunders == 1 ? 'blunder' : 'blunders';
  return switch (outcome) {
    PlayerOutcome.win when blunders == 0 =>
      'A clean win${acc == null ? '' : ': $acc'} and no blunders.',
    PlayerOutcome.win => 'A win${acc == null ? '' : ' at $acc'}, with $blunders $noun to tidy up.',
    PlayerOutcome.loss when blunders == 0 =>
      'A close fight${acc == null ? '' : ': $acc'} and no blunders.',
    PlayerOutcome.loss => '${acc ?? 'Good moves'}, but $blunders $noun decided it.',
    _ =>
      'A draw${acc == null ? '' : ' at $acc'}${blunders == 0 ? ' with no blunders' : ', with $blunders $noun'}.',
  };
}
