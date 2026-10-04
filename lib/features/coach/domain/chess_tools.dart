// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart' show Side;
import 'package:llm_tool/llm_tool.dart';

part 'chess_tools.g.dart';

// The coach's tools as the model sees them. `llm_tool_generator`
// turns each function into a ToolDefinition (`<name>Tool`, all of them in
// [chessTools]) with a JSON Schema built from its parameters, and `call()`
// checks the model's arguments against it.
//
// The functions only turn valid arguments into a [CoachCommand]; CoachTools
// runs it, with the engine, the stored games and what this question has
// verified so far.

/// What the model asked for, with its arguments checked and typed.
sealed class CoachCommand {
  const CoachCommand();
}

final class AnalyzePosition extends CoachCommand {
  const AnalyzePosition(this.fen);
  final String fen;
}

final class GetGameMistakes extends CoachCommand {
  const GetGameMistakes(this.gameId);
  final int gameId;
}

final class GetMyStats extends CoachCommand {
  const GetMyStats();
}

final class EvaluateMove extends CoachCommand {
  const EvaluateMove(this.fen, this.move);
  final String fen;
  final String move;
}

final class GetPosition extends CoachCommand {
  const GetPosition(this.gameId, this.moveNumber, this.side);
  final int gameId;
  final int moveNumber;
  final Side side;
}

/// Stockfish's evaluation and best line for a chess position. Use it to
/// check a move or to look deeper at a position from a game.
@LlmTool(name: 'analyze_position')
AnalyzePosition analyzePosition(@Param('The position in FEN.') String fen) => AnalyzePosition(fen);

/// The player's mistakes in one reviewed game: each move, the evaluation
/// before and after, Stockfish's best move and line, what the move allowed,
/// and the position before it (FEN). "best_line_material" and
/// "allowed_material" are the mover's material change in pawns at the end of
/// each line, left out when nothing changes.
@LlmTool(name: 'get_game_mistakes')
GetGameMistakes getGameMistakes(
  @Param('A game id from the list of games.', name: 'game_id') int gameId,
) => GetGameMistakes(gameId);

/// The player's results across their recent games: by opening and colour,
/// mistakes and blunders per game and by game phase, losses from winning
/// positions, and their three costliest moves.
@LlmTool(name: 'get_my_stats')
GetMyStats getMyStats() => const GetMyStats();

/// Stockfish's verdict on one move in a position: whether it's legal, the
/// evaluation after it and after Stockfish's best move (both for the side
/// making the move, in pawns; 10 means a forced win, -10 a forced loss), the
/// pawns it loses, and the opponent's best reply. Use it when the player
/// asks about a move that wasn't played, e.g. "what about Nf3 instead?". An
/// illegal move comes back with the legal moves.
@LlmTool(name: 'evaluate_move')
EvaluateMove evaluateMove(
  @Param('The position before the move, in FEN, copied from a tool result.') String fen,
  @Param('The move, in SAN (Nf3, exd5, O-O, e8=Q) or UCI (g1f3).') String move,
) => EvaluateMove(fen, move);

/// One move of a game, by its number as the player says it ("move 14"): the
/// move played, the positions before and after it (FEN), and, if the game
/// was reviewed, Stockfish's facts about it. Use it for a move the player
/// names that isn't among the mistakes already looked up.
@LlmTool(name: 'get_position')
GetPosition getPosition(
  @Param('A game id from the list of games.', name: 'game_id') int gameId,
  @Param(
    'The move number, as on a score sheet: 14 for "14. Nf3" or "14...Nf6".',
    name: 'move_number',
  )
  int moveNumber,
  @Param('Which side made the move.') Side side,
) => GetPosition(gameId, moveNumber, side);
