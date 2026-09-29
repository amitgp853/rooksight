import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/board_style.dart';
import '../../core/board/landing_square.dart';
import '../../core/board/move_wise_board.dart';
import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_failure_text.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/display_settings.dart';
import '../../core/storage/game_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../engine/chess_engine.dart';
import '../../engine/engine_provider.dart';
import '../games/games_screen.dart' show movesLabel, timeControlLabel;
import '../games/widgets/delete_game_sheet.dart';
import '../play/domain/game_state.dart';
import '../play/widgets/move_strip.dart';
import '../play/widgets/result_copy.dart' show moveLabel;
import 'domain/game_analysis.dart';
import 'domain/moment_text.dart';
import 'domain/move_review.dart';
import 'domain/position_eval.dart';
import 'review_controller.dart';
import 'widgets/eval_bar.dart';
import 'widgets/eval_graph.dart';
import 'widgets/key_moment_card.dart';
import 'widgets/move_table.dart';
import 'widgets/quality_chip.dart';

/// Game review (`design/source/Review.dc.html`): Stockfish's verdict on every
/// move, accuracy, the evaluation graph and the key moments.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.gameId, this.initialPly});

  final String gameId;

  /// Moves played in the position shown first; the final position if null.
  final int? initialPly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(gameId);
    final state = id == null
        ? const ReviewState(phase: ReviewPhase.notFound)
        : ref.watch(reviewControllerProvider(id));
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Review'),
        actions: [
          if (id != null && state.saved != null)
            IconButton(
              tooltip: 'Ask AI Coach about this game',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => context.push(Routes.coachAbout(id)),
            ),
          if (id != null && state.analysis != null)
            IconButton(
              tooltip: 'Share report card',
              icon: const Icon(Icons.ios_share),
              onPressed: () => context.push(Routes.reportCard('$id')),
            ),
          if (id != null && state.saved != null)
            IconButton(
              tooltip: 'Delete game',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirmed = await confirmDeleteGame(
                  context,
                  state.saved!.record,
                  reduceMotion: shouldReduceMotion(context, ref),
                );
                if (!confirmed) return;
                await ref.read(gameRepositoryProvider).delete(id);
                if (!context.mounted) return;
                // Back where the game was opened from, or to the list.
                context.canPop() ? context.pop() : context.go(Routes.games);
              },
            ),
        ],
      ),
      body: switch ((state.phase, state.saved, state.analysis)) {
        (ReviewPhase.notFound, _, _) => Center(
          child: Text(
            'This game couldn’t be found.',
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
        ),
        (_, final saved?, final analysis?) => _ReviewBody(
          gameId: id!,
          initialPly: initialPly,
          state: state,
          saved: saved,
          analysis: analysis,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({
    required this.gameId,
    this.initialPly,
    required this.state,
    required this.saved,
    required this.analysis,
  });

  final int gameId;
  final int? initialPly;
  final ReviewState state;
  ReviewPhase get phase => state.phase;
  final SavedGame saved;
  final GameAnalysis analysis;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

/// Where a tap further down the page came from: [key]'s widget, scrolled
/// [delta] past its top. The "Back to…" pill returns there.
typedef _ReturnSpot = ({String label, GlobalKey key, double delta});

/// A line played on the board from a position of the game: Stockfish's best
/// line from a key moment, or moves the player tries. Playing a move from
/// either keeps the line going, and a new move replaces what came after it.
class _Line {
  _Line(this.from, this.game, {this.step = 0, required this.yours});

  /// The game position the line starts from (moves played before it).
  final int from;

  /// The line, starting from that position.
  final GameState game;

  /// Moves of the line shown on the board.
  int step;

  /// The player's own moves, rather than Stockfish's line.
  final bool yours;
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  /// Moves played in the position on the board: opens on the final position.
  late int _ply = (widget.initialPly ?? widget.analysis.game.moves.length).clamp(
    0,
    widget.analysis.game.moves.length,
  );
  MoveFilter _filter = MoveFilter.all;
  _Line? _line;
  Timer? _lineTimer;
  final _scroll = ScrollController();

  /// Where the player was reading before a tap brought the board up.
  _ReturnSpot? _returnTo;
  final _momentKeys = <int, GlobalKey>{};
  final _movesKey = GlobalKey();

  /// Brass arrow for Stockfish's best move in the position shown. Off by
  /// default, so the player can think first.
  bool _showBest = false;

  /// Stockfish's evaluations of line positions, by FEN: each is searched
  /// once, so stepping back and forth is instant.
  final _lineEvals = <String, PositionEval>{};
  final _searching = <String>{};

  late final _board = ChessboardController(game: _gameData());

  /// The position before the move shows briefly (with the arrow) before the
  /// best move plays.
  static const _bestMoveDelay = Duration(milliseconds: 500);

  GameAnalysis get _analysis => widget.analysis;
  Side get _player => widget.saved.record.playerSide;

  @override
  void dispose() {
    _lineTimer?.cancel();
    _scroll.dispose();
    _board.dispose();
    super.dispose();
  }

  /// The position on the board and the move that led to it.
  ({Position position, Move? lastMove}) get _shown {
    final line = _line;
    if (line != null) {
      return (
        position: line.game.history[line.step],
        lastMove: line.step == 0 ? null : line.game.moves[line.step - 1].move,
      );
    }
    final game = _analysis.game;
    return (position: game.history[_ply], lastMove: _ply == 0 ? null : game.moves[_ply - 1].move);
  }

  /// Both sides can move, from any position: moves start or extend a line.
  GameData _gameData() {
    final (:position, :lastMove) = _shown;
    return GameData(
      fen: position.fen,
      lastMove: lastMove,
      playerSide: position.isGameOver ? PlayerSide.none : PlayerSide.both,
      sideToMove: position.turn,
      validMoves: makeLegalMoves(position),
      kingSquareInCheck: position.isCheck ? position.board.kingOf(position.turn) : null,
    );
  }

  /// Applies [change], then moves the board there and asks Stockfish about
  /// any line position it hasn't seen.
  void _update(VoidCallback change) {
    setState(change);
    _board.updatePosition(_gameData());
    final line = _line;
    if (line != null) {
      // The position shown, and the one before it (for the move's mark).
      for (final i in {line.step, if (line.step > 0) line.step - 1}) {
        unawaited(_evaluate(line, i));
      }
    }
  }

  /// Evaluation of position [i] of [line]: the game's own analysis for its
  /// first position, else Stockfish's result once it has one.
  PositionEval? _evalAt(_Line line, int i) {
    if (i == 0 && line.from < _analysis.evals.length) return _analysis.evals[line.from];
    return _lineEvals[line.game.history[i].fen];
  }

  Future<void> _evaluate(_Line line, int i) async {
    final position = line.game.history[i];
    final key = position.fen;
    if (_evalAt(line, i) != null || !_searching.add(key)) return;
    PositionEval? eval;
    try {
      if (!position.hasSomeLegalMoves) {
        eval = PositionEval.terminal(position);
      } else {
        final lines = await ref
            .read(chessEngineProvider)
            .search(key, SearchLimits(depth: ref.read(analysisDepthProvider).plies, lines: 2));
        eval = lines.isEmpty
            ? PositionEval.terminal(position)
            : PositionEval(
                score: lines.first.score,
                bestLine: lines.first.pv,
                secondScore: lines.length > 1 ? lines[1].score : null,
                depth: lines.first.depth,
              );
      }
    } on Object {
      eval = null; // No number this time; asking again later may work.
    } finally {
      _searching.remove(key);
    }
    if (eval != null && mounted) setState(() => _lineEvals[key] = eval!);
  }

  /// The player moved a piece on the board.
  void _onMove(Move move, {bool? viaDragAndDrop}) {
    final line = _line;
    final game = _analysis.game;
    if (line == null) {
      // The move played in the game just goes forward in the game.
      final next = game.history[_ply].isLegal(move) ? game.history[_ply].play(move) : null;
      if (_ply < game.moves.length && next?.fen == game.history[_ply + 1].fen) {
        _goTo(_ply + 1);
        return;
      }
      final started = GameState.start(game.history[_ply]).play(move);
      if (started == null) return _update(() {});
      _lineTimer?.cancel();
      _update(() => _line = _Line(_ply, started, step: 1, yours: true));
      return;
    }
    // Along the line: the next move of the line steps forward; anything else
    // replaces the rest of the line with the player's move.
    final here = line.game.undo(line.game.moves.length - line.step);
    final next = here.play(move);
    if (next == null) return _update(() {});
    final same =
        line.step < line.game.moves.length &&
        next.position.fen == line.game.history[line.step + 1].fen;
    _lineTimer?.cancel();
    _update(
      () => _line = same
          ? (line..step += 1)
          : _Line(line.from, next, step: line.step + 1, yours: true),
    );
  }

  Duration get _scrollDuration =>
      shouldReduceMotion(context, ref) ? Duration.zero : const Duration(milliseconds: 300);

  /// The scroll offset that puts the top of [key]'s widget at the top.
  double? _offsetOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box == null) return null;
    return RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
  }

  void _scrollTo(double offset) {
    if (!_scroll.hasClients) return;
    final to = offset.clamp(0.0, _scroll.position.maxScrollExtent);
    if (_scrollDuration == Duration.zero) return _scroll.jumpTo(to);
    unawaited(_scroll.animateTo(to, duration: _scrollDuration, curve: Curves.easeOutCubic));
  }

  /// Brings the board back into view after a tap further down the page. With
  /// [backTo], remembers the spot in [spot]'s widget for the "Back to…" pill.
  void _showBoard({String? backTo, GlobalKey? spot}) {
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    final top = spot == null ? null : _offsetOf(spot);
    if (backTo != null && top != null) {
      setState(() => _returnTo = (label: backTo, key: spot!, delta: _scroll.offset - top));
    }
    _scrollTo(0);
  }

  /// Scrolls back to where the player was reading. The spot is kept relative
  /// to its widget, as cards above it may have grown or shrunk meanwhile.
  void _goBack() {
    final spot = _returnTo;
    if (spot == null) return;
    setState(() => _returnTo = null);
    if (_offsetOf(spot.key) case final top?) _scrollTo(top + spot.delta);
  }

  /// Scrolls down to [moment]'s full card.
  void _readMoment(MoveReview moment) {
    setState(() => _returnTo = null);
    final key = _momentKeys[moment.index];
    if (key == null) return;
    if (_offsetOf(key) case final top?) _scrollTo(top - AppSpacing.s4);
  }

  /// The player scrolls the page themselves: they've moved on.
  bool _onScrollStart(ScrollStartNotification notification) {
    if (notification.depth == 0 && notification.dragDetails != null && _returnTo != null) {
      setState(() => _returnTo = null);
    }
    return false;
  }

  void _goTo(int ply) {
    _lineTimer?.cancel();
    _update(() {
      _line = null;
      _ply = ply.clamp(0, _analysis.game.moves.length);
    });
  }

  /// Shows the position before [moment] and plays Stockfish's best move
  /// there, then stops. The rest of its line is one tap away per move.
  void _playBestMove(MoveReview moment, {String? backTo, GlobalKey? spot}) {
    var line = GameState.start(_analysis.game.history[moment.index]);
    for (final uci in _analysis.evals[moment.index].bestLine.take(8)) {
      final move = Move.parse(uci);
      final next = move == null ? null : line.play(move);
      if (next == null) break;
      line = next;
    }
    if (line.moves.isEmpty) return;
    _showBoard(backTo: backTo, spot: spot);
    _lineTimer?.cancel();
    _update(() => _line = _Line(moment.index, line, yours: false));
    _lineTimer = Timer(_bestMoveDelay, () {
      if (_line?.step == 0) _update(() => _line!.step = 1);
    });
  }

  void _stepLine(int step) {
    _lineTimer?.cancel();
    _update(() => _line!.step = step.clamp(0, _line!.game.moves.length));
  }

  void _stopLine() {
    _lineTimer?.cancel();
    if (_line != null) _update(() => _line = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final analysis = _analysis;
    final game = analysis.game;
    final total = game.moves.length;
    final reviews = {for (final r in analysis.moves) r.index: r};
    final current = _ply > 0 ? reviews[_ply - 1] : null;
    final moments = analysis.isComplete ? analysis.keyMoments(_player) : const <MoveReview>[];
    final line = _line;
    final (:position, lastMove: _) = _shown;

    // The evaluation of the position shown. Along a line, until Stockfish has
    // looked at a position, the last known one stays (no jump to level).
    PositionEval? eval;
    var evalTurn = position.turn;
    if (line == null) {
      eval = _ply < analysis.evals.length ? analysis.evals[_ply] : null;
    } else {
      for (var i = line.step; i >= 0 && eval == null; i--) {
        eval = _evalAt(line, i);
        evalTurn = line.game.history[i].turn;
      }
    }

    // The mark of the move just played: the game's, or the line's once both
    // positions around it are evaluated.
    MoveReview? lineMove;
    if (line != null && line.step > 0) {
      final before = _evalAt(line, line.step - 1);
      final after = _evalAt(line, line.step);
      if (before != null && after != null) {
        lineMove = reviewMove(line.game, line.step - 1, evalBefore: before, evalAfter: after);
      }
    }
    final shapes = <Shape>{};
    final quality = line == null ? current?.quality : lineMove?.quality;
    final played = line == null
        ? (_ply == 0 ? null : (game.history[_ply - 1], game.moves[_ply - 1].move))
        : (line.step == 0
              ? null
              : (line.game.history[line.step - 1], line.game.moves[line.step - 1].move));
    final target = played == null ? null : landingSquare(played.$1, played.$2);
    if (quality != null && target != null) {
      shapes.add(
        CustomShape(
          orig: target,
          child: Align(
            alignment: Alignment.topRight,
            child: QualityDisc(quality: quality, size: 16),
          ),
        ),
      );
    }
    if (line != null && !line.yours && line.step == 0) {
      // Stockfish's move itself, before it plays.
      final next = line.game.moves.first.move;
      if (next is NormalMove) {
        shapes.add(
          Arrow(
            color: colors.focus.withValues(alpha: 0.85),
            orig: next.from,
            dest: next.to,
            scale: 0.8,
          ),
        );
      }
    } else if (_showBest && eval != null && evalTurn == position.turn) {
      if (Move.parse(eval.bestMove ?? '') case final NormalMove best) {
        shapes.add(hintArrow(colors, from: best.from, to: best.to));
      }
    }

    // The key moment on the board, summed up right under it.
    final noteMoment = line == null ? moments.where((m) => m.index + 1 == _ply).firstOrNull : null;
    final reduceMotion = shouldReduceMotion(context, ref);
    final returnTo = _returnTo;

    final record = widget.saved.record;
    final page = ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      children: [
        _Header(record: record, analysis: analysis),
        EvalBar(eval: eval, toMove: evalTurn, orientation: _player),
        MoveWiseBoard(controller: _board, orientation: _player, shapes: shapes, onMove: _onMove),
        if (line != null && !line.yours)
          _ReplayBar(
            title: line.step <= 1
                ? 'Best move: ${bestMoveLabel(analysis, line.from) ?? ''}'
                : 'Stockfish’s line · ${line.step} of ${line.game.moves.length}',
            subtitle: line.step <= 1
                ? 'instead of ${moveLabel(game, line.from)}'
                : [for (final m in line.game.moves.take(line.step)) m.san].join(' '),
            onFirst: line.step > 0 ? () => _stepLine(0) : null,
            onPrevious: line.step > 0 ? () => _stepLine(line.step - 1) : null,
            onNext: line.step < line.game.moves.length ? () => _stepLine(line.step + 1) : null,
            onLast: _stopLine,
            lastIcon: Icons.close,
            lastTooltip: 'Back to the game',
          )
        else if (line != null)
          _ReplayBar(
            title: line.step == 0
                ? 'Your line'
                : 'Your line · ${moveLabel(line.game, line.step - 1)}${lineMove?.quality?.symbol ?? ''}',
            subtitle: _lineVerdict(line, lineMove),
            onFirst: line.step > 0 ? () => _stepLine(0) : null,
            onPrevious: line.step > 0 ? () => _stepLine(line.step - 1) : null,
            onNext: line.step < line.game.moves.length ? () => _stepLine(line.step + 1) : null,
            onLast: _stopLine,
            lastIcon: Icons.close,
            lastTooltip: 'Back to the game',
          )
        else
          _ReplayBar(
            title: _ply == 0
                ? 'Start'
                : '${moveLabel(game, _ply - 1)}${current?.quality?.symbol ?? ''}',
            subtitle: 'move ${(_ply + 1) ~/ 2} of ${(total + 1) ~/ 2}',
            onFirst: _ply > 0 ? () => _goTo(0) : null,
            onPrevious: _ply > 0 ? () => _goTo(_ply - 1) : null,
            onNext: _ply < total ? () => _goTo(_ply + 1) : null,
            onLast: _ply < total ? () => _goTo(total) : null,
          ),
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: noteMoment == null
              ? const SizedBox(width: double.infinity)
              : _momentNote(noteMoment),
        ),
        if (line == null)
          MoveStrip(game: game, ply: _ply, onSelect: _goTo)
        else
          // Its own strip, so it starts scrolled to the line.
          MoveStrip(
            key: ValueKey(line.game.history.first.fen),
            game: line.game,
            ply: line.step,
            onSelect: _stepLine,
          ),
        _BoardTools(
          inLine: line != null,
          showBest: _showBest,
          onShowBest: (show) => setState(() => _showBest = show),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s4,
            AppSpacing.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.s6,
            children: [
              if (widget.phase != ReviewPhase.done)
                _Progress(phase: widget.phase, analysis: analysis, gameId: widget.gameId),
              _EvalCard(
                analysis: analysis,
                player: _player,
                ply: _ply,
                current: current,
                onSelect: _goTo,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.s3,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Key moments', style: type.heading),
                      if (analysis.isComplete)
                        Text(
                          '${moments.length} of ${(total + 1) ~/ 2} moves',
                          style: type.label.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  if (!analysis.isComplete)
                    Text(
                      'Key moments appear when the analysis finishes.',
                      style: type.body.copyWith(color: colors.textSecondary),
                    )
                  else if (moments.isEmpty)
                    Text(
                      'No big mistakes and no standout finds: a steady game.',
                      style: type.body.copyWith(color: colors.textSecondary),
                    )
                  else ...[
                    _ExplainPanel(
                      state: widget.state,
                      gameId: widget.gameId,
                      moments: moments.length,
                    ),
                    for (final moment in moments) _momentCard(moment, moments),
                  ],
                ],
              ),
              Column(
                key: _movesKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.s3,
                children: [
                  Text('Moves', style: type.heading),
                  MoveTable(
                    analysis: analysis,
                    player: _player,
                    ply: _ply,
                    filter: _filter,
                    onFilter: (filter) => setState(() => _filter = filter),
                    onSelect: (ply) {
                      _goTo(ply);
                      _showBoard(backTo: 'Back to moves', spot: _movesKey);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Stack(
      children: [
        NotificationListener<ScrollStartNotification>(onNotification: _onScrollStart, child: page),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.s6,
          child: SafeArea(
            top: false,
            child: Center(
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                child: returnTo == null
                    ? const SizedBox.shrink()
                    : _BackPill(key: ValueKey(returnTo), label: returnTo.label, onTap: _goBack),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The title and text of [moment]: the AI's words once it has explained
  /// it, else plain text.
  (MomentText, {bool ai}) _momentText(MoveReview moment) {
    final ai = widget.state.explanations?.moments[moment.index];
    return ai == null
        ? (templateText(_analysis, moment, player: _player), ai: false)
        : (MomentText(title: ai.title, body: ai.explanation), ai: true);
  }

  /// Whether the player can see Stockfish's move instead of [moment]'s.
  bool _canPlayBest(MoveReview moment) =>
      moment.side == _player &&
      moment.quality!.isError &&
      _analysis.evals[moment.index].bestLine.isNotEmpty;

  Widget _momentNote(MoveReview moment) {
    final (text, :ai) = _momentText(moment);
    return KeyMomentNote(
      key: ValueKey(moment.index),
      quality: moment.quality!,
      title: text.title,
      body: text.body,
      aiWritten: ai,
      onReadMore: () => _readMoment(moment),
      onShowBestMove: _canPlayBest(moment) ? () => _playBestMove(moment) : null,
    );
  }

  /// Under "Your line": where it starts, or how the last move did.
  String _lineVerdict(_Line line, MoveReview? move) {
    if (line.step == 0) {
      return line.from == 0
          ? 'from the start of the game'
          : 'after ${moveLabel(_analysis.game, line.from - 1)} in the game';
    }
    final after = _evalAt(line, line.step);
    if (after == null || move == null) return 'Stockfish is checking…';
    final eval = evalSummary(after, line.game.history[line.step].turn);
    final quality = move.quality;
    if (quality == null) return 'Good move · $eval';
    if (!quality.isError) return '${quality.label} · $eval';
    final best = sanLine(
      line.game.history[line.step - 1],
      _evalAt(line, line.step - 1)!.bestLine.take(1),
    ).firstOrNull;
    return '${quality.label} · $eval${best == null ? '' : ' · best was $best'}';
  }

  Widget _momentCard(MoveReview moment, List<MoveReview> moments) {
    // The moment on the board is expanded; otherwise the first one.
    final onBoard = moments.where((m) => m.index + 1 == _ply).firstOrNull ?? moments.first;
    final (text, ai: aiWritten) = _momentText(moment);
    final isPlayer = moment.side == _player;
    final record = widget.saved.record;
    final hasLine = _analysis.evals[moment.index].bestLine.isNotEmpty;
    final key = _momentKeys.putIfAbsent(moment.index, GlobalKey.new);
    return KeyMomentCard(
      key: key,
      moment: moment,
      aiWritten: aiWritten,
      lesson: widget.state.explanations?.moments[moment.index]?.lesson,
      isPlayer: isPlayer,
      moverName: isPlayer
          ? 'You'
          : record.source == GameSource.stockfish
          ? 'Stockfish'
          : (record.opponentName ?? 'Opponent'),
      title: text.title,
      body: text.body,
      change: evalChange(moment),
      selected: moment == onBoard,
      bestMove: bestMoveLabel(_analysis, moment.index),
      depth: _analysis.evals[moment.index].depth,
      onTap: () {
        _goTo(moment.index + 1);
        _showBoard(backTo: 'Back to key moments', spot: key);
      },
      onPlayBestMove: hasLine
          ? () => _playBestMove(moment, backTo: 'Back to key moments', spot: key)
          : null,
      onAskCoach: () => context.push(Routes.coachAbout(widget.gameId, moment.index)),
    );
  }
}

/// Floats over the page after a tap brought the board up: back to where the
/// player was reading.
class _BackPill extends StatelessWidget {
  const _BackPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = StadiumBorder(side: BorderSide(color: colors.border));
    return Material(
      color: colors.bgElevated,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.s2,
            children: [
              Icon(Icons.arrow_downward_rounded, size: 18, color: colors.focus),
              Text(label, style: context.type.label.copyWith(color: colors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under the board: that pieces can be moved, and the best-move arrow.
class _BoardTools extends StatelessWidget {
  const _BoardTools({required this.inLine, required this.showBest, required this.onShowBest});

  final bool inLine;
  final bool showBest;
  final ValueChanged<bool> onShowBest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.s1, AppSpacing.s2, 0),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: colors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              inLine ? 'Keep moving to explore' : 'Move a piece to try your own line',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
            ),
          ),
          Semantics(
            toggled: showBest,
            child: TextButton.icon(
              onPressed: () => onShowBest(!showBest),
              style: TextButton.styleFrom(
                foregroundColor: showBest ? colors.brass : colors.textSecondary,
                backgroundColor: showBest ? colors.brass.withValues(alpha: 0.12) : null,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                textStyle: type.label,
              ),
              icon: Icon(showBest ? Icons.lightbulb : Icons.lightbulb_outline, size: 18),
              label: const Text('Best move'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The result, who it was against, and both sides' accuracy.
class _Header extends StatelessWidget {
  const _Header({required this.record, required this.analysis});

  final GameRecord record;
  final GameAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final outcome = switch (record.outcome) {
      PlayerOutcome.win => 'Win',
      PlayerOutcome.draw => 'Draw',
      PlayerOutcome.loss => 'Loss',
      PlayerOutcome.unknown => 'Game',
    };
    final score = switch (record.result) {
      '1-0' => '1–0',
      '0-1' => '0–1',
      '1/2-1/2' => '½–½',
      _ => null,
    };
    final opponent = record.source == GameSource.stockfish
        ? 'Stockfish'
        : (record.opponentName ?? 'Opponent');
    final rating = record.opponentRating ?? record.engineElo;
    final details = [
      rating == null ? 'vs $opponent' : 'vs $opponent $rating',
      ?timeControlLabel(record),
      movesLabel(record),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 4, AppSpacing.gutter, 14),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  score == null ? outcome : '$outcome · $score',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.heading,
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _Accuracy(label: 'You', value: analysis.accuracy(record.playerSide), highlight: true),
          // A long name wouldn't fit here; it's on the left already.
          _Accuracy(
            label: record.source == GameSource.stockfish ? 'Stockfish' : 'Opponent',
            value: analysis.accuracy(record.playerSide.opposite),
          ),
        ],
      ),
    );
  }
}

/// One side's accuracy: name and number centred in a tile of fixed width,
/// so both tiles line up.
class _Accuracy extends StatelessWidget {
  const _Accuracy({required this.label, required this.value, this.highlight = false});

  final String label;
  final double? value;
  final bool highlight;

  static const width = 84.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      label: '$label accuracy ${value?.toStringAsFixed(1) ?? 'not known yet'}',
      excludeSemantics: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? colors.focus.withValues(alpha: 0.12) : colors.bgRaised,
          borderRadius: AppRadius.smAll,
        ),
        child: Column(
          spacing: 2,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: type.label.copyWith(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value == null ? '–' : '${value!.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: type.heading.copyWith(
                fontSize: 17,
                color: highlight
                    ? Color.lerp(colors.focus, colors.textPrimary, 0.3)
                    : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The move on the board and the buttons to step through the game.
class _ReplayBar extends StatelessWidget {
  const _ReplayBar({
    required this.title,
    required this.subtitle,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    this.lastIcon = Icons.last_page,
    this.lastTooltip = 'Last move',
  });

  final String title;
  final String subtitle;
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;
  final IconData lastIcon;
  final String lastTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed, {bool raised = false}) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(44),
            foregroundColor: raised ? colors.textPrimary : colors.textSecondary,
            backgroundColor: raised ? colors.bgRaised : Colors.transparent,
            disabledForegroundColor: colors.textTertiary.withValues(alpha: 0.4),
            disabledBackgroundColor: raised ? colors.bgRaised : Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        );

    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          spacing: 4,
          children: [
            button(Icons.first_page, 'First move', onFirst),
            button(Icons.chevron_left, 'Previous move', onPrevious, raised: true),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: context.type.mono,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(
                      fontSize: 12,
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            button(Icons.chevron_right, 'Next move', onNext, raised: true),
            button(lastIcon, lastTooltip, onLast),
          ],
        ),
      ),
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.phase, required this.analysis, required this.gameId});

  final ReviewPhase phase;
  final GameAnalysis analysis;
  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final failed = phase == ReviewPhase.failed;
    final positions = analysis.game.history.length;
    final done = analysis.evals.length;
    if (failed) {
      return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.coral.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: colors.coral.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.s3,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    'Stockfish couldn’t finish the analysis.',
                    style: type.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(colors.coral, colors.textPrimary, 0.35),
                    ),
                  ),
                  Text(
                    'It stopped at move ${(done + 1) ~/ 2} of ${positions ~/ 2}. '
                    'The game itself is saved.',
                    style: type.label.copyWith(
                      fontWeight: FontWeight.w400,
                      height: 19 / 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              FilledButton(
                onPressed: ref.read(reviewControllerProvider(gameId).notifier).retry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: type.heading.copyWith(fontSize: 14),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s2,
        children: [
          Text('Analysing with Stockfish', style: type.body.copyWith(fontWeight: FontWeight.w600)),
          ...[
            Text(
              'Move ${(done + 1) ~/ 2} of ${positions ~/ 2} · you can look around meanwhile',
              style: type.label.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w400),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: positions == 0 ? null : done / positions,
                minHeight: 6,
                color: colors.focus,
                backgroundColor: colors.bgElevated,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvalCard extends StatelessWidget {
  const _EvalCard({
    required this.analysis,
    required this.player,
    required this.ply,
    required this.current,
    required this.onSelect,
  });

  final GameAnalysis analysis;
  final Side player;
  final int ply;
  final MoveReview? current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final moves = (analysis.game.moves.length + 1) ~/ 2;
    final marks = {1, for (var m = 10; m < moves; m += 10) m, moves}.toList()..sort();
    final quality = current?.quality;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EVALUATION', style: type.overline.copyWith(color: colors.textSecondary)),
              if (current != null)
                Text(
                  evalChange(current!),
                  style: type.mono.copyWith(
                    fontSize: 13,
                    color: quality != null && quality.isError
                        ? qualityColor(colors, quality)
                        : colors.textSecondary,
                  ),
                ),
            ],
          ),
          EvalGraph(analysis: analysis, player: player, ply: ply, onSelect: onSelect),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final mark in marks)
                Text('$mark', style: type.mono.copyWith(fontSize: 11, color: colors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks the AI to explain the key moments (one Gemini call, kept with the
/// game), and shows where that stands.
class _ExplainPanel extends ConsumerWidget {
  const _ExplainPanel({required this.state, required this.gameId, required this.moments});

  final ReviewState state;
  final int gameId;
  final int moments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final controller = ref.read(reviewControllerProvider(gameId).notifier);
    final caption = type.label.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w400);

    Widget panel(List<Widget> children) => Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s2,
        children: children,
      ),
    );

    switch (state.explainPhase) {
      case ExplainPhase.done:
        final explanations = state.explanations;
        final summary = explanations?.summary ?? explanations?.verdict;
        final focus = explanations?.focus ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s2,
          children: [
            if (summary != null || focus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.s4),
                decoration: BoxDecoration(
                  color: colors.focus.withValues(alpha: 0.08),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: colors.focus.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s2,
                  children: [
                    if (summary != null) ...[
                      Text('SUMMARY', style: type.overline.copyWith(color: colors.textSecondary)),
                      Text(summary, style: type.body),
                    ],
                    if (focus.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text('WORK ON', style: type.overline.copyWith(color: colors.textSecondary)),
                      for (final (i, item) in focus.indexed)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.s2,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: type.mono.copyWith(fontSize: 14, color: colors.focus),
                            ),
                            Expanded(child: Text(item, style: type.body)),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(child: Text('Explained by AI · moves and claims checked', style: caption)),
                TextButton(onPressed: controller.explain, child: const Text('Explain again')),
              ],
            ),
          ],
        );
      case ExplainPhase.running:
        // An agent step row from the design: "running".
        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: colors.focus.withValues(alpha: 0.4)),
          ),
          child: Row(
            spacing: AppSpacing.s3,
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.focus),
              ),
              Expanded(
                child: Text(
                  'Asking AI about $moments ${moments == 1 ? 'moment' : 'moments'}…',
                  style: type.body.copyWith(
                    fontSize: 14,
                    color: Color.lerp(colors.focus, colors.textPrimary, 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      case ExplainPhase.failed:
        return panel([
          Text(llmFailureText(state.explainError), style: type.body.copyWith(color: colors.coral)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: controller.explain, child: const Text('Try again')),
          ),
        ]);
      case ExplainPhase.none when !ref.watch(llmConfiguredProvider):
        return panel([
          Text(
            'Want these explained in plain words?',
            style: type.body.copyWith(fontWeight: FontWeight.w600),
          ),
          Text('AI explanations aren’t set up on this device yet.', style: caption),
        ]);
      case ExplainPhase.none:
        return panel([
          OutlinedButton.icon(
            onPressed: controller.explain,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('Explain key moments'),
          ),
          Text(
            'Every move the AI mentions is checked.',
            textAlign: TextAlign.center,
            style: caption,
          ),
        ]);
    }
  }
}
