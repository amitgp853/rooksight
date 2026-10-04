// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chess_tools.dart';

// **************************************************************************
// ToolGenerator
// **************************************************************************

final analyzePositionTool = ToolDefinition(
  name: "analyze_position",
  description:
      "Stockfish's evaluation and best line for a chess position. Use it to check a move or to look deeper at a position from a game.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "fen": {"type": "string", "description": "The position in FEN."},
    },
    "required": ["fen"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => analyzePosition(args["fen"] as String),
);

final getGameMistakesTool = ToolDefinition(
  name: "get_game_mistakes",
  description:
      "The player's mistakes in one reviewed game: each move, the evaluation before and after, Stockfish's best move and line, what the move allowed, and the position before it (FEN). \"best_line_material\" and \"allowed_material\" are the mover's material change in pawns at the end of each line, left out when nothing changes.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "game_id": {"type": "integer", "description": "A game id from the list of games."},
    },
    "required": ["game_id"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getGameMistakes((args["game_id"] as num).toInt()),
);

final getMyStatsTool = ToolDefinition(
  name: "get_my_stats",
  description:
      "The player's results across their recent games: by opening and colour, mistakes and blunders per game and by game phase, losses from winning positions, and their three costliest moves.",
  parametersSchema: {
    "type": "object",
    "properties": {},
    "required": [],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getMyStats(),
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
final List<ToolDefinition> chessTools = [analyzePositionTool, getGameMistakesTool, getMyStatsTool];
