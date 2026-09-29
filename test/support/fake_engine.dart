import 'package:dartchess/dartchess.dart';
import 'package:move_wise/engine/chess_engine.dart';
import 'package:move_wise/engine/uci.dart';

/// A [ChessEngine] for tests: answers after [delay] with the lines from
/// [reply], or by default with the first legal move.
class FakeEngine implements ChessEngine {
  FakeEngine({this.delay = Duration.zero, this.reply});

  Duration delay;
  List<EngineLine> Function(String fen)? reply;

  /// When true, searches throw.
  bool fail = false;

  final searches = <({String fen, SearchLimits limits})>[];

  @override
  Future<List<EngineLine>> search(String fen, SearchLimits limits) async {
    searches.add((fen: fen, limits: limits));
    await Future<void>.delayed(delay);
    if (fail) throw StateError('engine failed');
    return reply?.call(fen) ?? [line(firstLegalMove(fen))];
  }

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}

  static String firstLegalMove(String fen) {
    final position = Chess.fromSetup(Setup.parseFen(fen));
    final entry = position.legalMoves.entries.firstWhere((e) => e.value.isNotEmpty);
    return NormalMove(from: entry.key, to: entry.value.first!).uci;
  }
}

EngineLine line(String uci, {int rank = 1, int cp = 0}) =>
    EngineLine(rank: rank, depth: 10, score: EngineScore.centipawns(cp), pv: [uci]);
