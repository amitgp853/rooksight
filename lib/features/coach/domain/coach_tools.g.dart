// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_tools.dart';

// **************************************************************************
// ToolGenerator
// **************************************************************************

/// The @LlmTool methods of [CoachTools] as tools.
extension CoachToolsLlmTools on CoachTools {
  /// Every tool of this [CoachTools], bound to this instance, e.g. to send
  /// to an LLM or look up by name.
  List<ToolDefinition<ToolOutcome>> get llmTools => [
    ToolDefinition(
      name: "analyze_position",
      description:
          "Stockfish's evaluation and best line for a chess position. Use it to check a move or to look deeper at a position from a game. The evaluation is in pawns from the point of view of the side to move (\"side_to_move\" in the result): positive means the side to move is better. It's capped at ±10; a forced mate comes back as \"mate_in\" instead (positive: the side to move mates; negative: it gets mated).",
      parametersSchema: {
        "type": "object",
        "properties": {
          "fen": {
            "type": "string",
            "description": "The position in FEN, copied from a tool result.",
          },
        },
        "required": ["fen"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => _analyzePosition(args["fen"] as String),
    ),
    ToolDefinition(
      name: "get_game_mistakes",
      description:
          "The player's mistakes in one reviewed game, with the game's summary: opponent, date, the player's colour, ratings, opening, result and how it ended, accuracy, and counts of blunders, mistakes and inaccuracies. Then the moments, in game order: the player's costliest mistakes (six at most), and always the move the question is about. Each moment has the move and its verdict, the evaluation before and after (in pawns, for the side that moved), Stockfish's best move and line, what the move allowed, pieces left hanging, any forced mate, and the position before it (FEN). \"best_line_material\" and \"allowed_material\" are the mover's material change in pawns at the end of each line, left out when nothing changes. A game that isn't reviewed comes back with only a note.",
      parametersSchema: {
        "type": "object",
        "properties": {
          "game_id": {"type": "integer", "description": "A game id from the list of games."},
        },
        "required": ["game_id"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => _gameMistakes((args["game_id"] as num).toInt()),
    ),
    ToolDefinition(
      name: "get_my_stats",
      description:
          "The player's results across their last 50 games: by opening and colour, mistakes and blunders per game and by game phase, losses from winning positions, their three costliest moves and their top three weaknesses.",
      parametersSchema: {
        "type": "object",
        "properties": {},
        "required": [],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => _stats(),
    ),
    ToolDefinition(
      name: "evaluate_move",
      description:
          "Stockfish's verdict on one move in a position: whether it's legal, the evaluation after it and after Stockfish's best move (both for the side making the move, in pawns; 10 means a forced win, -10 a forced loss), the pawns it loses, and the opponent's best reply. Use it when the player asks about a move that wasn't played, e.g. \"what about Nf3 instead?\". An illegal move comes back with the legal moves.",
      parametersSchema: {
        "type": "object",
        "properties": {
          "fen": {
            "type": "string",
            "description": "The position before the move, in FEN, copied from a tool result.",
          },
          "move": {
            "type": "string",
            "description": "The move, in SAN (Nf3, exd5, O-O, e8=Q) or UCI (g1f3).",
          },
        },
        "required": ["fen", "move"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => _evaluateMove(args["fen"] as String, args["move"] as String),
    ),
    ToolDefinition(
      name: "get_position",
      description:
          "One move of a game, by its number as the player says it (\"move 14\"): the move played, the positions before and after it (FEN), and, if the game was reviewed, Stockfish's facts about it. Use it for a move the player names that isn't among the mistakes already looked up.",
      parametersSchema: {
        "type": "object",
        "properties": {
          "game_id": {"type": "integer", "description": "A game id from the list of games."},
          "move_number": {
            "type": "integer",
            "description":
                "The move number, as on a score sheet: 14 for \"14. Nf3\" or \"14…Nf6\".",
          },
          "side": {
            "type": "string",
            "enum": ["white", "black"],
            "description": "Which side made the move.",
          },
        },
        "required": ["game_id", "move_number", "side"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => _position(
        (args["game_id"] as num).toInt(),
        (args["move_number"] as num).toInt(),
        Side.values.byName(args["side"] as String),
      ),
    ),
  ];
}
