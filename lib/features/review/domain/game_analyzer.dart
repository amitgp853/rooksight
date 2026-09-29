import '../../../engine/chess_engine.dart';
import '../../play/domain/game_state.dart';
import 'position_eval.dart';

/// Runs Stockfish over every position of a game, at full strength and a fixed
/// depth, asking for the top two moves (the second tells "the one good move"
/// apart from one of several).
class GameAnalyzer {
  GameAnalyzer(this._engine);

  final ChessEngine _engine;

  /// Evaluates [game]'s positions after the [done] ones already known,
  /// emitting the growing list after each. Stops early when [isCancelled].
  Stream<List<PositionEval>> analyze(
    GameState game, {
    required int depth,
    List<PositionEval> done = const [],
    bool Function()? isCancelled,
  }) async* {
    final evals = [...done];
    for (var ply = evals.length; ply < game.history.length; ply++) {
      if (isCancelled?.call() ?? false) return;
      final position = game.history[ply];
      if (!position.hasSomeLegalMoves) {
        evals.add(PositionEval.terminal(position));
      } else {
        final lines = await _engine.search(position.fen, SearchLimits(depth: depth, lines: 2));
        evals.add(
          lines.isEmpty
              ? PositionEval.terminal(position)
              : PositionEval(
                  score: lines.first.score,
                  bestLine: lines.first.pv,
                  secondScore: lines.length > 1 ? lines[1].score : null,
                  depth: lines.first.depth,
                ),
        );
      }
      yield List.unmodifiable(evals);
    }
  }
}
