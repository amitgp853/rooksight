// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../engine/chess_engine.dart';
import '../../../engine/uci.dart';
import '../../review/domain/move_review.dart';
import '../../review/domain/position_eval.dart';
import 'analysis_tree.dart';

/// What Stockfish has found in one position so far.
@immutable
class PositionAnalysis {
  const PositionAnalysis({required this.lines, required this.depth});

  /// No legal moves: checkmate or stalemate.
  const PositionAnalysis.terminal() : lines = const [], depth = 0;

  /// Best first; scores from the side to move.
  final List<EngineLine> lines;
  final int depth;

  bool get isTerminal => lines.isEmpty;

  /// As the review's evaluations, for move marks and the eval bar.
  PositionEval evalOf(Position position) => lines.isEmpty
      ? PositionEval.terminal(position)
      : PositionEval(
          score: lines.first.score,
          bestLine: lines.first.pv,
          secondScore: lines.length > 1 ? lines[1].score : null,
          depth: depth,
        );
}

/// The analysis board's state: the moves explored, the position shown, and
/// Stockfish running on it (spec: "Free exploration"). Stockfish deepens step
/// by step, so numbers show within a moment and firm up; moving on stops
/// the search at once. Everything runs on the phone.
class AnalysisSession extends ChangeNotifier {
  AnalysisSession({required ChessEngine engine, required this.tree, AnalysisNode? current})
    : _engine = engine,
      _current = current ?? tree.root.end;

  final ChessEngine _engine;
  final AnalysisTree tree;
  AnalysisNode _current;

  /// Depths searched on the way to [targetDepth].
  static const depthSteps = [8, 12, 16, 20, 24];
  static int get targetDepth => depthSteps.last;

  /// Lines Stockfish shows.
  static const lineCount = 3;

  /// The best-move arrow and move marks wait for at least this depth.
  static const trustedDepth = 12;

  /// Depth of the "what does the opponent threaten" search.
  static const threatDepth = 14;

  final _analyses = <String, PositionAnalysis>{};
  final _threats = <String, EngineLine?>{};
  int _run = 0;
  bool _disposed = false;

  bool _engineOn = true;
  bool _threatOn = false;
  bool _thinking = false;
  bool _failed = false;

  AnalysisNode get current => _current;
  Position get position => _current.position;
  bool get engineOn => _engineOn;
  bool get threatOn => _threatOn;

  /// Stockfish is still deepening on the position shown.
  bool get thinking => _thinking;

  /// The last search failed (the engine didn't answer).
  bool get failed => _failed;

  /// Stockfish's findings in the position shown, if any yet.
  PositionAnalysis? get analysis => analysisOf(_current.position);

  PositionAnalysis? analysisOf(Position position) => _analyses[_key(position)];

  /// What the side not to move threatens (Threat on), once searched.
  EngineLine? get threat => _threatOn ? _threats[_key(position)] : null;

  /// The mark of the move into [node] (vs Stockfish's best before it), once
  /// both positions around it have been searched deeply enough.
  MoveReview? reviewOf(AnalysisNode node) {
    if (node.isRoot) return null;
    final before = analysisOf(node.before);
    final after = analysisOf(node.position);
    if (before == null || after == null) return null;
    if (before.depth < trustedDepth || (!after.isTerminal && after.depth < trustedDepth)) {
      return null;
    }
    final game = tree.gameTo(node);
    return reviewMove(
      game,
      node.ply - 1,
      evalBefore: before.evalOf(node.before),
      evalAfter: after.evalOf(node.position),
    );
  }

  /// Starts analysing the position shown (again, after [pause]).
  void start() => _analyse();

  /// Stops searching without turning the engine off, e.g. while another
  /// screen (a game, the coach) needs Stockfish. [start] carries on.
  void pause() {
    _run++;
    _thinking = false;
    _engine.stop();
  }

  void goTo(AnalysisNode node) {
    if (node == _current) return;
    _current = node;
    _changed(analyse: true);
  }

  /// Plays [move] from the position shown. Returns false if it's illegal.
  bool play(Move move) {
    final next = tree.play(_current, move);
    if (next == null) return false;
    goTo(next);
    return true;
  }

  /// Plays [uci] moves from the position shown (e.g. part of an engine
  /// line), as far as they are legal.
  void playLine(Iterable<String> uci) {
    var node = _current;
    for (final m in uci) {
      final move = Move.parse(m);
      final next = move == null ? null : tree.play(node, move);
      if (next == null) break;
      node = next;
    }
    goTo(node);
  }

  void back() {
    if (_current.parent case final parent?) goTo(parent);
  }

  void forward() {
    if (_current.children.firstOrNull case final next?) goTo(next);
  }

  void toStart() => goTo(tree.root);

  void toEnd() => goTo(_current.end);

  void promote(AnalysisNode node) {
    tree.promote(node);
    _changed();
  }

  /// Removes [node] and what follows; the board steps back if it was there.
  void delete(AnalysisNode node) {
    if (node.isRoot) return;
    final parent = node.parent!;
    tree.delete(node);
    if (_current.isInside(node)) {
      _current = parent;
      _changed(analyse: true);
    } else {
      _changed();
    }
  }

  /// Takes back the move just played (it goes from the list too).
  void takeBack() => delete(_current);

  void setEngine({required bool on}) {
    if (on == _engineOn) return;
    _engineOn = on;
    if (!on) {
      _run++;
      _thinking = false;
      _engine.stop();
    }
    _changed(analyse: on);
  }

  void setThreat({required bool on}) {
    if (on == _threatOn) return;
    _threatOn = on;
    _changed();
    if (on && _engineOn && !_thinking) unawaited(_searchThreat(_run));
  }

  void _changed({bool analyse = false}) {
    if (_disposed) return;
    notifyListeners();
    if (analyse) _analyse();
  }

  void _analyse() {
    final run = ++_run;
    _engine.stop();
    if (!_engineOn) return;
    unawaited(_deepen(run));
  }

  Future<void> _deepen(int run) async {
    final position = _current.position;
    final key = _key(position);
    bool stale() => _disposed || run != _run;

    if (!position.hasSomeLegalMoves) {
      _analyses[key] = const PositionAnalysis.terminal();
      _thinking = false;
      if (!stale()) notifyListeners();
      return;
    }
    final known = _analyses[key]?.depth ?? 0;
    final steps = depthSteps.where((d) => d > known).toList();
    _thinking = steps.isNotEmpty;
    _failed = false;
    notifyListeners();

    for (final depth in steps) {
      final List<EngineLine> lines;
      try {
        lines = await _engine.search(
          position.fen,
          SearchLimits(depth: depth, lines: lineCount, stoppable: true),
        );
      } on Object {
        if (stale()) return;
        _thinking = false;
        _failed = true;
        notifyListeners();
        return;
      }
      if (stale()) return;
      // A stopped search returns what it had, which may be shallower.
      final reached = lines.isEmpty ? depth : lines.first.depth;
      if (reached >= (_analyses[key]?.depth ?? 0)) {
        _analyses[key] = PositionAnalysis(lines: lines, depth: reached);
      }
      notifyListeners();
    }
    _thinking = false;
    notifyListeners();
    if (_threatOn) await _searchThreat(run);
  }

  /// The best move for the side NOT to move, as if it were its turn.
  Future<void> _searchThreat(int run) async {
    final position = _current.position;
    final key = _key(position);
    if (_threats.containsKey(key)) return;
    if (position.isCheck || !position.hasSomeLegalMoves) {
      _threats[key] = null;
      return;
    }
    final Position passed;
    try {
      final setup = Setup.parseFen(position.fen);
      passed = Chess.fromSetup(
        Setup(
          board: setup.board,
          turn: setup.turn.opposite,
          castlingRights: setup.castlingRights,
          halfmoves: setup.halfmoves,
          fullmoves: setup.fullmoves,
        ),
      );
    } on PositionSetupException {
      _threats[key] = null;
      return;
    }
    try {
      final lines = await _engine.search(
        passed.fen,
        const SearchLimits(depth: threatDepth, stoppable: true),
      );
      if (_disposed || run != _run) return;
      _threats[key] = lines.firstOrNull;
      notifyListeners();
    } on Object {
      // No threat shown this time.
    }
  }

  /// Positions that differ only in move counters share an analysis.
  static String _key(Position position) => position.fen.split(' ').take(4).join(' ');

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _engine.stop();
    super.dispose();
  }
}
