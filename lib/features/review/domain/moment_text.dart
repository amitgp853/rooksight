import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/chess/uci.dart';
import '../../play/widgets/result_copy.dart' show moveLabel, moveNumber;
import '../widgets/quality_chip.dart' show formatEval;
import 'game_analysis.dart';
import 'move_review.dart';

/// A key moment's title and explanation.
@immutable
class MomentText {
  const MomentText({required this.title, required this.body});

  final String title;
  final String body;
}

/// Plain descriptions built from the numbers alone: shown until the AI
/// explains the moments, and whenever it can't. The opponent's slips are
/// described from [player]'s side, as chances.
MomentText templateText(GameAnalysis analysis, MoveReview moment, {required Side player}) {
  final label = moveLabel(analysis.game, moment.index);
  final best = bestMoveLabel(analysis, moment.index);
  final change = '${formatEval(moment.before)} to ${formatEval(moment.after)}';
  final cost = moment.loss.toStringAsFixed(1);

  if (moment.side != player && moment.quality != null && moment.quality!.isError) {
    final big = moment.quality == MoveQuality.blunder;
    return MomentText(
      title: '$label was a ${big ? 'blunder' : 'mistake'}',
      body:
          '${big ? 'A big chance' : 'A chance'} for you: it cost them $cost pawns.'
          '${best == null ? '' : ' Their best was $best.'}',
    );
  }
  return switch (moment.quality) {
    MoveQuality.blunder => MomentText(
      title: '$label was a blunder',
      body: 'The evaluation fell from $change.${best == null ? '' : ' Stockfish preferred $best.'}',
    ),
    MoveQuality.mistake => MomentText(
      title: '$label was a mistake',
      body: 'The evaluation went from $change.${best == null ? '' : ' $best was stronger.'}',
    ),
    MoveQuality.inaccuracy => MomentText(
      title: '$label was inaccurate',
      body: 'A small slip, from $change.${best == null ? '' : ' $best kept more.'}',
    ),
    MoveQuality.best => MomentText(
      title: '$label — the one good move',
      body: 'Every alternative was at least a pawn worse.',
    ),
    MoveQuality.brilliant => MomentText(
      title: '$label — a sound sacrifice',
      body: 'Stockfish’s top choice, and it gives up material to get there.',
    ),
    null => MomentText(title: label, body: ''),
  };
}

/// Stockfish's preferred move instead of move [index], numbered like the
/// game (`23. Rd1`), or null if unknown.
String? bestMoveLabel(GameAnalysis analysis, int index) {
  final line = bestLineSan(analysis, index, maxPlies: 1);
  if (line.isEmpty) return null;
  final number = moveNumber(analysis.game, index);
  return analysis.game.moves[index].side == Side.white
      ? '$number. ${line.first}'
      : '$number…${line.first}';
}

/// Stockfish's best line from the position before move [index], in SAN.
List<String> bestLineSan(GameAnalysis analysis, int index, {int maxPlies = 6}) {
  if (index >= analysis.evals.length) return const [];
  return sanLine(analysis.game.history[index], analysis.evals[index].bestLine.take(maxPlies));
}

/// [uci] moves from [start] in SAN, stopping at the first illegal one.
List<String> sanLine(Position start, Iterable<String> uci) {
  final sans = <String>[];
  var position = start;
  for (final text in uci) {
    final move = parseUci(text);
    if (move == null || !position.isLegal(move)) break;
    final (next, san) = position.makeSan(move);
    sans.add(san);
    position = next;
  }
  return sans;
}

/// The positions along [uci] from [start], and the moves between them.
({List<Position> positions, List<Move> moves}) playLine(Position start, Iterable<String> uci) {
  final positions = [start];
  final moves = <Move>[];
  for (final text in uci) {
    final move = parseUci(text);
    if (move == null || !positions.last.isLegal(move)) break;
    positions.add(positions.last.play(move));
    moves.add(move);
  }
  return (positions: positions, moves: moves);
}

/// Loss in pawns for display on a card, e.g. `+0.4 → −2.9`.
String evalChange(MoveReview moment) =>
    '${formatEval(moment.before)} → ${formatEval(moment.after)}';
