import 'package:dartchess/dartchess.dart';

import '../../../engine/uci.dart';
import '../../play/domain/game_state.dart' show pieceValue;
import '../../review/widgets/quality_chip.dart' show formatEval;

/// A move number or a move of an engine line, as the line shows it.
typedef LineToken = ({String text, bool isNumber, int index});

/// [pv] (UCI) played from [from] as SAN with move numbers, up to [max] moves
/// or the first move that isn't legal: `7.` `Bg5` `h6` `8.` `Bh4`. A move's
/// [LineToken.index] is its place in [pv].
List<LineToken> lineTokens(Position from, List<String> pv, {int max = 8}) {
  final tokens = <LineToken>[];
  var position = from;
  for (final (i, uci) in pv.take(max).indexed) {
    final parsed = Move.parse(uci);
    if (parsed == null || !position.isLegal(parsed)) break;
    final move = parsed is NormalMove ? position.normalizeMove(parsed) : parsed;
    if (i == 0 || position.turn == Side.white) {
      tokens.add((
        text: position.turn == Side.white ? '${position.fullmoves}.' : '${position.fullmoves}…',
        isNumber: true,
        index: i,
      ));
    }
    final (next, san) = position.makeSanUnchecked(move);
    tokens.add((text: san, isNumber: false, index: i));
    position = next;
  }
  return tokens;
}

/// A score from the side to move, as White's signed number: `+0.4`, `−1.8`,
/// `M3` (either side mating), `#` once mated.
String whiteEvalText(EngineScore score, Side toMove) {
  final mate = score.mate;
  if (mate != null) return mate == 0 ? '#' : 'M${mate.abs()}';
  final pawns = score.centipawns! / 100;
  return formatEval(toMove == Side.white ? pawns : -pawns);
}

/// Whether White is better (or level) by [score], given [toMove].
bool whiteAhead(EngineScore score, Side toMove) {
  final forMover = score.mate != null ? (score.mate! > 0 ? 1 : -1) : score.centipawns!;
  return (toMove == Side.white ? forMover : -forMover) >= 0;
}

/// White's win, draw and loss chances in whole percent, from Stockfish's
/// [wdl] for the side to move. They add up to 100.
({int white, int draw, int black}) whiteWdl(Wdl wdl, Side toMove) {
  final (win, loss) = toMove == Side.white ? (wdl.win, wdl.loss) : (wdl.loss, wdl.win);
  // Rounded one by one they can make 101 (50.5 / 49.5): Black takes the rest.
  final white = (win / 10).round().clamp(0, 100);
  final draw = (wdl.draw / 10).round().clamp(0, 100 - white);
  return (white: white, draw: draw, black: 100 - white - draw);
}

/// Material on the board from White's side: `+1`, `=`, `−2`.
String materialText(Position position) {
  var diff = 0;
  for (final role in Role.values) {
    diff +=
        (position.board.piecesOf(Side.white, role).size -
            position.board.piecesOf(Side.black, role).size) *
        pieceValue(role);
  }
  if (diff == 0) return '=';
  return diff > 0 ? '+$diff' : '−${-diff}';
}

/// "…Na5, going after your bishop on c4": what [threat] (the best move for
/// the side not to move in [position], as if it were its turn) is after.
/// "Your" is [viewer]'s side.
String threatText(Position position, EngineLine threat, {required Side viewer}) {
  final mover = position.turn.opposite;
  final Position passed;
  try {
    final setup = Setup.parseFen(position.fen);
    passed = Chess.fromSetup(
      Setup(
        board: setup.board,
        turn: mover,
        castlingRights: setup.castlingRights,
        halfmoves: setup.halfmoves,
        fullmoves: setup.fullmoves,
      ),
    );
  } on PositionSetupException {
    return '';
  }
  final parsed = Move.parse(threat.move);
  if (parsed is! NormalMove || !passed.isLegal(parsed)) return '';
  final move = passed.normalizeMove(parsed);
  final (after, san) = passed.makeSanUnchecked(move);
  final shown = mover == Side.black ? '…$san' : san;

  final victim = position.turn;
  String owner(Role role, Square square) =>
      '${victim == viewer ? 'your' : (victim == Side.white ? 'White’s' : 'Black’s')} '
      '${role.name} on ${square.name}';

  final taken = passed.board.pieceAt(move.to);
  if (taken != null && taken.color == victim) {
    return '$shown, taking ${owner(taken.role, move.to)}';
  }
  if (after.isCheck) return '$shown, with check';
  // The most valuable piece the moved piece now attacks.
  (Role, Square)? target;
  for (final (square, piece) in after.board.pieces) {
    if (piece.color != victim || piece.role == Role.king) continue;
    if (!after.board.attacksTo(square, mover).has(move.to)) continue;
    if (target == null || pieceValue(piece.role) > pieceValue(target.$1)) {
      target = (piece.role, square);
    }
  }
  if (target != null && pieceValue(target.$1) >= 3) {
    return '$shown, going after ${owner(target.$1, target.$2)}';
  }
  return shown;
}
