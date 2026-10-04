// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:llm_tool/llm_tool.dart';

import '../../../core/chess/move_check.dart';
import '../../../core/chess/uci.dart';
import '../../../core/llm/llm_client.dart';
import '../../../core/storage/analysis_repository.dart';
import '../../../core/storage/game_repository.dart';
import '../../../engine/chess_engine.dart';
import '../../../engine/uci.dart';
import '../../play/domain/game_state.dart';
import '../../play/domain/pgn_import.dart';
import '../../play/widgets/result_copy.dart' show moveLabel;
import '../../review/domain/game_analysis.dart';
import '../../review/domain/moment_facts.dart';
import '../../review/domain/moment_text.dart';
import '../../review/domain/move_review.dart';
import '../../review/domain/position_eval.dart';
import '../../stats/domain/player_stats.dart';
import '../../stats/domain/weaknesses.dart';
import 'coach_move.dart';

part 'coach_tools.g.dart';

/// One line in the coach's list of steps: "running" until [done].
@immutable
class AgentStep {
  const AgentStep(this.label, {this.detail, this.done = false});

  final String label;

  /// Shown under a finished step, e.g. `Rd1 +0.4 · depth 16`.
  final String? detail;
  final bool done;
}

/// A tool's result for the model (compact) and its finished step.
@immutable
class ToolOutcome {
  const ToolOutcome(this.result, this.step);

  final Map<String, Object?> result;
  final AgentStep step;
}

/// What a question is about: a whole game (attached in the chat), or one
/// move of it (asked from a review).
@immutable
class CoachFocus {
  const CoachFocus({required this.gameId, this.index, required this.label});

  final int gameId;

  /// The move asked about; null for the whole game.
  final int? index;

  /// For the chip and the question bubble: `2. g4`, or `vs sayles0 · 27 Sep`.
  final String label;

  bool get isMove => index != null;
}

/// The coach's tools. Everything they return comes from Stockfish, the
/// stored games and their analyses; the model only chooses what to call.
///
/// The tools remember every move they reported ([moves]) and every game move
/// they described ([gameMoves]): an answer may only mention those.
@LlmToolset()
class CoachTools {
  CoachTools({
    required GameRepository games,
    required AnalysisRepository analyses,
    required ChessEngine engine,
    required this.depth,
  }) : _games = games,
       _analyses = analyses,
       _engine = engine;

  final GameRepository _games;
  final AnalysisRepository _analyses;
  final ChessEngine _engine;

  /// Stockfish's search depth for [analyzePosition].
  final int depth;

  // The tools' names, as set by the @LlmTool annotations below.
  static const analyzePosition = 'analyze_position';
  static const getGameMistakes = 'get_game_mistakes';
  static const getMyStats = 'get_my_stats';
  static const evaluateMove = 'evaluate_move';
  static const getPosition = 'get_position';

  /// Games listed in each question, newest first.
  static const recentGames = 10;

  /// Errors per game sent to the model.
  static const maxMistakes = 6;

  /// The tools, generated from the @LlmTool methods below.
  late final _tools = llmTools;

  /// The tools as the model sees them.
  late final declarations = [
    for (final tool in _tools)
      LlmToolSpec(
        name: tool.name,
        description: tool.description,
        parameters: tool.parametersSchema,
      ),
  ];

  late final _byName = {for (final tool in _tools) tool.name: tool};

  /// The running step's label, for the tool [run] is running.
  void Function(String label) _onStart = (_) {};

  /// What each tool looks up, in the player's words, for a failed step.
  static const _lookups = {
    analyzePosition: 'Stockfish’s view of a position',
    getGameMistakes: 'The mistakes in your game',
    getMyStats: 'Your stats',
    evaluateMove: 'Stockfish’s view of a move',
    getPosition: 'A move from your game',
  };

  /// Moves (SAN without `+`/`#`) the tools have reported.
  final moves = <String>{};

  /// Game moves the tools have described, by `(game id, move index)`.
  final gameMoves = <(int, int), CoachMove>{};

  /// What the tools have verified so far, to save with a chat: reopened
  /// later, its answers may still mention these ([restore]).
  Map<String, Object?> get memory => {
    'moves': moves.toList(),
    'cards': [for (final move in gameMoves.values) move.toJson()],
  };

  /// Brings back what an earlier session verified (see [memory]).
  void restore(Map<String, Object?> memory) {
    final saved = memory['moves'];
    if (saved is List) moves.addAll(saved.whereType<String>());
    final cards = memory['cards'];
    if (cards is List) {
      for (final move in cards.map(CoachMove.fromJson).nonNulls) {
        gameMoves[(move.gameId, move.index)] = move;
      }
    }
  }

  /// Positions from games, by FEN without the move counters, so a later
  /// look at the same position can say which move it was.
  final _positions = <String, ({CoachMove move, String? best})>{};

  /// The move a review asked about: always included in that game's mistakes.
  CoachFocus? focus;

  /// A short list of the player's recent games for the question, so the
  /// model can pick game ids, and the move asked about, if any.
  Future<String> context() async {
    // One row per game under a header, rather than JSON repeating every key:
    // the same facts in about a third of the tokens, sent with every call.
    final saved = (await _games.watchAll().first).take(recentGames).toList();
    final buffer = StringBuffer(
      'The player\'s recent games, newest first '
      '(game_id | date | vs | you_played | result | reviewed):',
    );
    for (final s in saved) {
      final reviewed = (await _analyses.analysis(s.id))?.complete ?? false;
      buffer.write(
        '\n${s.id} | ${_date(s.record.endedAt)} | ${_opponent(s.record)} | '
        '${s.record.playerSide.name} | ${s.record.outcome.name} | ${reviewed ? 'yes' : 'no'}',
      );
    }
    if (saved.isEmpty) buffer.write('\nnone yet');
    if (focus case final focus?) {
      final saved = await _games.byId(focus.gameId);
      if (saved != null) {
        final record = saved.record;
        final reviewed = (await _analyses.analysis(saved.id))?.complete ?? false;
        final move = focus.index == null ? null : await _focusLabel(focus);
        buffer.write(
          move != null
              ? '\nThe question is about game ${saved.id}, move_id ${focus.index} ($move).'
              : '\nThe question is about game ${saved.id}: vs ${_opponent(record)}, '
                    '${_date(record.endedAt)}, the player had ${record.playerSide.name} and '
                    'the result was a ${record.outcome.name}'
                    '${reviewed ? '' : ' (not reviewed yet, so no mistakes to look at)'}.',
        );
      }
    }
    return buffer.toString();
  }

  /// Runs [call]. [onStart] gets the running step's label once known.
  /// Never throws: failures go back to the model as `error`.
  Future<ToolOutcome> run(LlmToolCall call, {required void Function(String label) onStart}) async {
    final tool = _byName[call.name];
    if (tool == null) {
      return ToolOutcome({'error': 'Unknown tool ${call.name}.'}, _failed('Couldn’t look that up'));
    }
    try {
      _onStart = onStart;
      return await tool.call(call.args);
    } on ToolArgumentException catch (error) {
      // The message is written for the model, so it can fix its call; the
      // player sees what the coach was trying to look up.
      return ToolOutcome({
        'error': '$error',
      }, _failed('Couldn’t look that up', detail: _lookups[tool.name]));
    } on Object catch (error) {
      debugPrint('Coach tool ${call.name} failed: $error');
      return ToolOutcome({
        'error': 'The tool failed.',
      }, _failed('Something went wrong', detail: _lookups[tool.name]));
    }
  }

  /// Stockfish's evaluation and best line for a chess position. Use it to
  /// check a move or to look deeper at a position from a game. Evals are in
  /// pawns for the side to move, capped at ±10; "mate_in" is a forced mate,
  /// negative when the side to move gets mated.
  @LlmTool(name: 'analyze_position')
  Future<ToolOutcome> _analyzePosition(
    @Param('The position in FEN, copied from a tool result.') String fen,
  ) async {
    final Position position;
    try {
      position = Chess.fromSetup(Setup.parseFen(fen));
    } on Object {
      _onStart('Reading a position…');
      return ToolOutcome({'error': 'Not a valid FEN.'}, _failed('Couldn’t read that position'));
    }
    final known = _positions[_key(position.fen)];
    _onStart(
      known == null
          ? 'Asking Stockfish about this position…'
          : 'Asking Stockfish about move ${_number(known.move.label)}…',
    );
    if (position.isGameOver) {
      final result = position.isCheckmate ? 'checkmate' : 'draw';
      return ToolOutcome({'result': result}, AgentStep('Game over: $result', done: true));
    }

    final lines = await _engine.search(position.fen, SearchLimits(depth: depth));
    if (lines.isEmpty) {
      return ToolOutcome({'error': 'Stockfish gave no line.'}, _failed('Stockfish had no answer'));
    }
    final line = lines.first;
    final sans = sanLine(position, line.pv.take(6));
    moves.addAll(sans.map(MoveCheck.strip));
    final score = _score(line.score);
    final best = sans.firstOrNull;
    final verified = best != null && known?.best == best;
    return ToolOutcome(
      {
        'side_to_move': position.turn.name,
        ...score.json,
        'best_move': ?best,
        if (sans.isNotEmpty) 'line': sans.join(' '),
        'depth': line.depth,
      },
      AgentStep(
        verified
            ? 'Verified best move: $best'
            : best == null
            ? 'Stockfish looked at the position'
            : 'Stockfish’s best move: $best',
        detail: [?best, score.label, 'depth ${line.depth}'].join(' · '),
        done: true,
      ),
    );
  }

  /// The player's mistakes in one reviewed game: each move, the evaluation
  /// before and after, Stockfish's best move and line, what the move allowed,
  /// and the position before it (FEN). "best_line_material" and
  /// "allowed_material" are the mover's material change in pawns at the end of
  /// each line, left out when nothing changes. Also the game's summary
  /// (ratings, opening, result, accuracy, error counts) and always the move
  /// the question is about.
  @LlmTool(name: 'get_game_mistakes')
  Future<ToolOutcome> _gameMistakes(
    @Param('A game id from the list of games.', name: 'game_id') int id,
  ) async {
    final saved = await _games.byId(id);
    if (saved == null) {
      _onStart('Looking for a game…');
      return ToolOutcome({'error': 'No game with id $id.'}, _failed('Couldn’t find that game'));
    }
    final record = saved.record;
    _onStart('Looking at your game vs ${_opponent(record)}…');

    final stored = await _analyses.analysis(saved.id);
    final game = gameFromPgn(record.pgn);
    if (stored == null || !stored.complete) {
      return ToolOutcome({
        'game_id': saved.id,
        'reviewed': false,
        'note': 'Not analysed yet. The player can open the game\'s review to analyse it.',
      }, AgentStep('Your game vs ${_opponent(record)}', detail: 'Not reviewed yet', done: true));
    }

    final analysis = GameAnalysis(game, stored.evals.map(PositionEval.fromJson).toList());
    final side = record.playerSide;
    final errors = analysis.moves.where((m) => m.side == side && (m.quality?.isError ?? false));
    final worst = (errors.toList()..sort((a, b) => b.loss.compareTo(a.loss))).take(maxMistakes);
    final focused = focus?.gameId == saved.id && focus!.isMove
        ? analysis.moves.where((m) => m.index == focus!.index)
        : const <MoveReview>[];
    final chosen = {...worst, ...focused}.toList()..sort((a, b) => a.index.compareTo(b.index));

    final mistakes = [
      for (final m in chosen)
        {
          ...factsFor(analysis, m, player: side).toJson()..remove('id'),
          'move_id': m.index,
          'fen_before': game.history[m.index].fen,
        },
    ];
    for (final m in chosen) {
      _remember(saved, game, m.index, analysis: analysis, quality: m.quality);
    }

    final counts = analysis.counts(side);
    final accuracy = analysis.accuracy(side);
    return ToolOutcome(
      {
        'game_id': saved.id,
        'vs': _opponent(record),
        'date': _date(record.endedAt),
        'you_played': side.name,
        'your_rating': ?record.playerRating,
        'opponent_rating': ?(record.opponentRating ?? record.engineElo),
        'opening': ?namedOpening(record, game),
        'result': record.outcome.name,
        'ending': ?record.endReason,
        if (accuracy != null) 'accuracy': accuracy.round(),
        'blunders': counts[MoveQuality.blunder],
        'mistakes': counts[MoveQuality.mistake],
        'inaccuracies': counts[MoveQuality.inaccuracy],
        'moments': mistakes,
      },
      AgentStep(
        'Your game vs ${_opponent(record)}',
        detail: [
          _count(counts[MoveQuality.blunder]!, 'blunder'),
          _count(counts[MoveQuality.mistake]!, 'mistake'),
          if (accuracy != null) 'accuracy ${accuracy.round()}%',
        ].join(' · '),
        done: true,
      ),
    );
  }

  /// The player's results across their last 50 games: by opening and colour,
  /// mistakes and blunders per game and by game phase, losses from winning
  /// positions, their three costliest moves and their top three weaknesses.
  @LlmTool(name: 'get_my_stats')
  Future<ToolOutcome> _stats() async {
    final total = (await _games.watchAll().first).length;
    final checked = total < 50 ? total : 50;
    _onStart('Checking your last $checked ${checked == 1 ? 'game' : 'games'}…');

    final games = await loadStatsGames(_games, _analyses, limit: checked);
    final stats = PlayerStats.of(games);
    final weaknesses = findWeaknesses(games).take(3);
    for (final w in stats.worst) {
      _remember(
        w.game.saved,
        w.game.game,
        w.moment.index,
        analysis: w.game.analysis,
        quality: w.moment.quality,
      );
    }
    double? round(double? x) => x == null ? null : double.parse(x.toStringAsFixed(2));

    return ToolOutcome(
      {
        'games': stats.games,
        'wins': stats.wins,
        'draws': stats.draws,
        'losses': stats.losses,
        'openings': [
          for (final o in stats.byOpening.take(5))
            {
              'name': o.name,
              'as': o.side.name,
              'games': o.games,
              'wins': o.wins,
              'draws': o.draws,
              'losses': o.losses,
            },
        ],
        'reviewed_games': stats.reviewed,
        'top_weaknesses': [
          for (final w in weaknesses)
            {'name': w.title, 'evidence': w.detail, 'games': w.games.length},
        ],
        if (stats.reviewed == 0)
          'note': 'No games reviewed yet, so there are no error stats. Reviewing a game adds them.'
        else ...{
          'average_accuracy': ?stats.averageAccuracy?.round(),
          'blunders_per_game': round(stats.blundersPerGame),
          'mistakes_per_game': round(stats.mistakesPerGame),
          'errors_by_phase': {
            for (final MapEntry(key: phase, value: c) in stats.errorsByPhase.entries)
              phase: {'mistakes': c.mistakes, 'blunders': c.blunders},
          },
          'losses_from_winning_positions': stats.lossesFromWinning,
          'costliest_moves': [
            for (final w in stats.worst)
              {
                'game_id': w.game.saved.id,
                'move_id': w.moment.index,
                'move': moveLabel(w.game.game, w.moment.index),
                'verdict': w.moment.quality?.label,
                'pawns_lost': double.parse(w.moment.loss.toStringAsFixed(1)),
                'best_move': ?bestMoveLabel(w.game.analysis!, w.moment.index),
              },
          ],
        },
      },
      AgentStep(
        'Checked your last $checked ${checked == 1 ? 'game' : 'games'}',
        detail: [
          '${stats.games} games',
          '${stats.reviewed} reviewed',
          _count(stats.losses, 'loss', 'losses'),
        ].join(' · '),
        done: true,
      ),
    );
  }

  /// Stockfish's verdict on one move in a position: whether it's legal, the
  /// evaluation after it and after Stockfish's best move (both for the side
  /// making the move, in pawns; 10 means a forced win, -10 a forced loss), the
  /// pawns it loses, and the opponent's best reply. Use it when the player
  /// asks about a move that wasn't played, e.g. "what about Nf3 instead?". An
  /// illegal move comes back with the legal moves.
  @LlmTool(name: 'evaluate_move')
  Future<ToolOutcome> _evaluateMove(
    @Param('The position before the move, in FEN, copied from a tool result.') String fen,
    @Param('The move, in SAN (Nf3, exd5, O-O, e8=Q) or UCI (g1f3).', name: 'move') String text,
  ) async {
    final Position position;
    try {
      position = Chess.fromSetup(Setup.parseFen(fen));
    } on Object {
      _onStart('Reading a position…');
      return ToolOutcome({'error': 'Not a valid FEN.'}, _failed('Couldn’t read that position'));
    }
    if (position.isGameOver) {
      return ToolOutcome({
        'error': 'The game is over in this position.',
      }, _failed('The game was already over there'));
    }
    final move = _parseMove(position, text);
    if (move == null) {
      // The legal moves let the model correct a typo or a mix-up of sides.
      return ToolOutcome({
        'legal': false,
        'error': '$text is not a legal move in this position.',
        'legal_moves': MoveCheck.legalSans(position).toList()..sort(),
      }, _failed('That move isn’t legal there', detail: text));
    }

    final mover = position.turn;
    final (after, san) = position.makeSan(move);
    final known = _positions[_key(position.fen)];
    _onStart(
      known == null ? 'Trying $san with Stockfish…' : 'Trying $san instead of ${known.move.label}…',
    );

    final best = (await _engine.search(position.fen, SearchLimits(depth: depth))).firstOrNull;
    if (best == null) {
      return ToolOutcome({'error': 'Stockfish gave no line.'}, _failed('Stockfish had no answer'));
    }
    final bestLine = sanLine(position, best.pv.take(6));
    final bestEval = cappedPawns(best.score);
    final playedBest = bestLine.firstOrNull == san;

    // The move's eval for the side making it. Stockfish's best move needs no
    // second search (two searches would disagree a little on the same move).
    final double moveEval;
    var reply = const <String>[];
    if (after.isCheckmate) {
      moveEval = evalCap;
    } else if (after.isGameOver) {
      moveEval = 0;
    } else if (playedBest) {
      moveEval = bestEval;
      reply = bestLine.skip(1).toList();
    } else {
      final line = (await _engine.search(after.fen, SearchLimits(depth: depth))).firstOrNull;
      if (line == null) {
        return ToolOutcome({
          'error': 'Stockfish gave no line.',
        }, _failed('Stockfish had no answer'));
      }
      moveEval = -cappedPawns(line.score);
      reply = sanLine(after, line.pv.take(5));
    }
    final loss = playedBest ? 0.0 : max(0.0, bestEval - moveEval);
    final quality = playedBest ? null : errorQuality(loss: loss, after: moveEval);
    moves.addAll([san, ...bestLine, ...reply].map(MoveCheck.strip));

    return ToolOutcome(
      {
        'side_to_move': mover.name,
        'move': san,
        'legal': true,
        'verdict': playedBest ? 'best' : quality?.name ?? 'good',
        if (after.isCheckmate) 'result': 'checkmate' else if (after.isGameOver) 'result': 'draw',
        'eval_after_move': _round(moveEval),
        'best_move': ?bestLine.firstOrNull,
        'eval_after_best': _round(bestEval),
        if (!playedBest) ...{
          'pawns_lost': _round(loss, 1),
          if (bestLine.isNotEmpty) 'best_line': bestLine.join(' '),
        },
        if (reply.isNotEmpty) 'reply_line': reply.join(' '),
        'depth': best.depth,
      },
      AgentStep(
        playedBest
            ? 'Verified best move: $san'
            : switch (quality) {
                MoveQuality.blunder => '$san would be a blunder',
                MoveQuality.mistake => '$san would be a mistake',
                MoveQuality.inaccuracy => '$san would be an inaccuracy',
                _ => '$san holds up',
              },
        detail: [
          '$san ${_pawns(moveEval)}',
          if (!playedBest && bestLine.isNotEmpty) 'best ${bestLine.first} ${_pawns(bestEval)}',
          'depth ${best.depth}',
        ].join(' · '),
        done: true,
      ),
    );
  }

  /// One move of a game, by its number as the player says it ("move 14"): the
  /// move played, the positions before and after it (FEN), and, if the game
  /// was reviewed, Stockfish's facts about it. Use it for a move the player
  /// names that isn't among the mistakes already looked up.
  @LlmTool(name: 'get_position')
  Future<ToolOutcome> _position(
    @Param('A game id from the list of games.', name: 'game_id') int id,
    @Param(
      'The move number, as on a score sheet: 14 for "14. Nf3" or "14…Nf6".',
      name: 'move_number',
    )
    int number,
    @Param('Which side made the move.') Side side,
  ) async {
    final saved = await _games.byId(id);
    if (saved == null) {
      _onStart('Looking for a game…');
      return ToolOutcome({'error': 'No game with id $id.'}, _failed('Couldn’t find that game'));
    }
    final record = saved.record;
    final game = gameFromPgn(record.pgn);

    // Half-moves from the game's start (which may be a set-up position).
    final start = game.history.first;
    final index =
        (number - start.fullmoves) * 2 +
        (side == Side.black ? 1 : 0) -
        (start.turn == Side.black ? 1 : 0);
    if (index < 0 || index >= game.moves.length) {
      final asked = side == Side.white ? '$number.' : '$number…';
      return ToolOutcome(
        {
          'error': game.moves.isEmpty
              ? 'Game $id has no moves.'
              : 'Game $id has no move $asked: its last move is '
                    '${moveLabel(game, game.moves.length - 1)}.',
        },
        _failed(
          'Couldn’t find that move',
          detail: 'Move $number in your game vs ${_opponent(record)}',
        ),
      );
    }
    final label = moveLabel(game, index);
    _onStart('Finding $label in your game vs ${_opponent(record)}…');

    final played = {
      'game_id': saved.id,
      'move_id': index,
      'move': label,
      'by': side == record.playerSide ? 'player' : 'opponent',
      'fen_before': game.history[index].fen,
      'fen_after': game.history[index + 1].fen,
    };
    final stored = await _analyses.analysis(saved.id);
    final analysis = stored != null && stored.complete
        ? GameAnalysis(game, stored.evals.map(PositionEval.fromJson).toList())
        : null;
    if (analysis == null || index >= analysis.moves.length) {
      _remember(saved, game, index);
      return ToolOutcome({
        ...played,
        'reviewed': false,
      }, AgentStep(label, detail: 'vs ${_opponent(record)} · not reviewed yet', done: true));
    }

    final m = analysis.moves[index];
    _remember(saved, game, index, analysis: analysis, quality: m.quality);
    return ToolOutcome(
      {
        ...played,
        'reviewed': true,
        ...factsFor(analysis, m, player: record.playerSide).toJson()
          ..remove('id')
          ..remove('move')
          ..remove('by'),
      },
      AgentStep(
        label,
        detail: ['vs ${_opponent(record)}', ?m.quality?.label].join(' · '),
        done: true,
      ),
    );
  }

  /// Notes move [index] of a game as one the answer may mention and point
  /// to, with Stockfish's lines around it when the game was reviewed.
  void _remember(
    SavedGame saved,
    GameState game,
    int index, {
    GameAnalysis? analysis,
    MoveQuality? quality,
  }) {
    final best = analysis == null ? null : bestLineSan(analysis, index, maxPlies: 1).firstOrNull;
    final move = CoachMove(
      gameId: saved.id,
      index: index,
      label: moveLabel(game, index),
      quality: quality,
      best: best,
      fen: game.history[index + 1].fen,
      lastMove: game.moves[index].move,
      orientation: saved.record.playerSide,
      opponent: _opponent(saved.record),
      playedAt: saved.record.endedAt,
    );
    gameMoves[(saved.id, index)] = move;
    _positions[_key(game.history[index].fen)] = (move: move, best: best);
    moves.add(MoveCheck.strip(game.moves[index].san));
    if (analysis == null) return;
    for (final san in [...bestLineSan(analysis, index), ...bestLineSan(analysis, index + 1)]) {
      moves.add(MoveCheck.strip(san));
    }
  }

  /// [text] as a legal move in [position]: SAN (`Nf3`, `O-O`) or UCI
  /// (`g1f3`); null if it's neither, or not legal here.
  static Move? _parseMove(Position position, String text) {
    // Castling is often typed with zeros (0-0); no other move has a 0.
    final cleaned = text.trim().replaceAll('0', 'O');
    if (position.parseSan(cleaned) case final move?) return move;
    final uci = parseUci(cleaned.toLowerCase());
    return uci != null && position.isLegal(uci) ? uci : null;
  }

  Future<String?> _focusLabel(CoachFocus focus) async {
    final index = focus.index;
    final saved = await _games.byId(focus.gameId);
    if (saved == null || index == null) return null;
    final game = gameFromPgn(saved.record.pgn);
    return index < game.moves.length ? moveLabel(game, index) : null;
  }

  static AgentStep _failed(String label, {String? detail}) =>
      AgentStep(label, detail: detail, done: true);

  /// Board, side to move, castling and en passant: the same position
  /// whatever the move counters say.
  static String _key(String fen) => fen.split(' ').take(4).join(' ');

  /// `23` from `23. Nxd5` or `23…Nxd5`.
  static String _number(String label) => RegExp(r'^\d+').stringMatch(label) ?? label;

  static String _opponent(GameRecord record) =>
      record.opponentName ??
      (record.engineElo != null ? 'Stockfish ${record.engineElo}' : 'your opponent');

  static String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _count(int n, String one, [String? many]) =>
      '$n ${n == 1 ? one : (many ?? '${one}s')}';

  /// The score for the side to move, for the model and for the screen.
  static ({Map<String, Object?> json, String label}) _score(EngineScore score) {
    if (score.mate case final mate?) {
      return (json: {'mate_in': mate}, label: mate > 0 ? 'mate in $mate' : 'mated in ${-mate}');
    }
    final pawns = cappedPawns(score);
    return (json: {'eval': _round(pawns)}, label: _pawns(pawns));
  }

  /// `+0.4`, `−1.2`: an eval for the screen.
  static String _pawns(double pawns) {
    final text = pawns.toStringAsFixed(1);
    return pawns > 0 ? '+$text' : text.replaceFirst('-', '−');
  }

  static double _round(double pawns, [int digits = 2]) =>
      double.parse(pawns.toStringAsFixed(digits));
}
