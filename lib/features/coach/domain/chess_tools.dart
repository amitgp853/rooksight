// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:llm_tool_calling/llm_tool_calling.dart';

part 'chess_tools.g.dart';

// The coach's tools as the model sees them. `llm_tool_calling_generator`
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

/// Stockfish's evaluation and best line for a chess position. Use it to
/// check a move or to look deeper at a position from a game.
@Tool(name: 'analyze_position')
AnalyzePosition analyzePosition(@Param('The position in FEN.') String fen) => AnalyzePosition(fen);

/// The player's mistakes in one reviewed game: each move, the evaluation
/// before and after, Stockfish's best move and line, what the move allowed,
/// and the position before it (FEN). "best_line_material" and
/// "allowed_material" are the mover's material change in pawns at the end of
/// each line, left out when nothing changes.
@Tool(name: 'get_game_mistakes')
GetGameMistakes getGameMistakes(
  // Snake case to match the game_id in the prompt and every tool result.
  // ignore: non_constant_identifier_names
  @Param('A game id from the list of games.') int game_id,
) => GetGameMistakes(game_id);

/// The player's results across their recent games: by opening and colour,
/// mistakes and blunders per game and by game phase, losses from winning
/// positions, and their three costliest moves.
@Tool(name: 'get_my_stats')
GetMyStats getMyStats() => const GetMyStats();
