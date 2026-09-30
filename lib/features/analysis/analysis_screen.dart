import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/landing_square.dart';
import '../../core/board/move_wise_board.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/routing/app_router.dart';
import '../../core/storage/saved_position_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/move_wise_sheet.dart';
import '../../engine/engine_provider.dart';
import '../games/games_screen.dart' show shortDate;
import '../report_card/data/image_sharer.dart';
import '../review/widgets/eval_bar.dart';
import '../review/widgets/quality_chip.dart';
import '../scan/domain/board_setup.dart';
import '../scan/scan_check_screen.dart';
import 'domain/analysis_args.dart';
import 'domain/analysis_session.dart';
import 'domain/analysis_text.dart';
import 'domain/analysis_tree.dart';
import 'saved_positions_screen.dart' show PositionNameDialog;
import 'widgets/analysis_panels.dart';

/// The analysis board (`Analysis*.dc.html`): any position (from a scan, a
/// game or set up by hand) with Stockfish's evaluation, win/draw/loss
/// chances, its top three lines, the best-move and threat arrows, and free
/// play for both sides. New moves off the line become variations, each
/// marked against Stockfish's best. Runs on the phone; no AI.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key, required this.args, this.saved});

  final AnalysisArgs args;

  /// A saved position to reopen, with its moves; [args] is ignored then.
  final SavedPosition? saved;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  late AnalysisSession _session;
  late Side _orientation;
  late String _subtitle;
  late final ChessboardController _board;
  final _boardKey = GlobalKey();

  /// The saved position this board keeps up to date, once saved.
  int? _savedId;

  /// The moves and place last written, to skip writing when nothing moved.
  String? _savedState;
  Timer? _saveTimer;

  /// After a change, the save waits this long for more.
  static const _saveDelay = Duration(milliseconds: 800);

  /// Read once: the last save runs in [dispose], where `ref` can't be used.
  late final SavedPositionRepository _positions;

  @override
  void initState() {
    super.initState();
    _positions = ref.read(savedPositionRepositoryProvider);
    final saved = widget.saved;
    if (saved != null) {
      final tree = AnalysisTree.fromJson(_startPosition(saved.fen), saved.moves);
      _session = AnalysisSession(
        engine: ref.read(chessEngineProvider),
        tree: tree,
        current: tree.nodeAt(saved.path),
      )..addListener(_onChange);
      _orientation = saved.orientation == 'black' ? Side.black : Side.white;
      _subtitle = saved.title;
      _savedId = saved.id;
      _savedState = _stateOf(_session);
    } else {
      _session = _newSession(_startPosition(widget.args.fen), widget.args.moves, widget.args.ply);
      _orientation = widget.args.orientation;
      _subtitle = _subtitleFor(widget.args.source, _session);
    }
    _board = ChessboardController(game: _gameData());
    // Stockfish reports progress at once; start once this state can rebuild.
    scheduleMicrotask(() {
      if (mounted) _session.start();
    });
  }

  @override
  void dispose() {
    // Leaving: write any change still waiting.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_writeMoves());
    }
    _session
      ..removeListener(_onChange)
      ..dispose();
    _board.dispose();
    super.dispose();
  }

  static Position _startPosition(String fen) {
    try {
      return Chess.fromSetup(Setup.parseFen(fen));
    } on Object {
      return Chess.initial;
    }
  }

  /// The moves explored and where the board is, as saved.
  static String _stateOf(AnalysisSession session) =>
      jsonEncode([session.tree.toJson(), session.tree.pathTo(session.current)]);

  Future<void> _writeMoves() async {
    final id = _savedId;
    if (id == null) return;
    final state = _stateOf(_session);
    if (state == _savedState) return;
    _savedState = state;
    await _positions.updateMoves(
      id,
      moves: _session.tree.toJson(),
      path: _session.tree.pathTo(_session.current),
      now: DateTime.now(),
    );
  }

  String get _defaultTitle {
    final date = shortDate(DateTime.now());
    final source = widget.saved == null ? widget.args.source : null;
    return switch (source) {
      AnalysisSource.scan => 'Scanned position · $date',
      AnalysisSource.game => '${_subtitle.replaceFirst('From your game', 'Game')} · $date',
      _ => 'Position · $date',
    };
  }

  /// Saves the position (asking for a name), or says it's already saved.
  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_savedId != null) {
      messenger.showSnackBar(const SnackBar(content: Text('Saved. New moves are kept as you go.')));
      return;
    }
    final title = await showDialog<String>(
      context: context,
      builder: (context) => PositionNameDialog(
        title: 'Save position',
        initial: _defaultTitle,
        note:
            'Kept on this phone with the moves you explore. Open it again from Saved '
            'Positions on Home.',
      ),
    );
    if (title == null || !mounted) return;
    final tree = _session.tree;
    final id = await _positions.create((
      title: title,
      fen: tree.root.position.fen,
      moves: tree.toJson(),
      path: tree.pathTo(_session.current),
      source: (widget.saved == null ? widget.args.source : AnalysisSource.setup).name,
      orientation: _orientation.name,
    ), DateTime.now());
    if (!mounted) return;
    setState(() {
      _savedId = id;
      _savedState = _stateOf(_session);
    });
    messenger.showSnackBar(const SnackBar(content: Text('Saved to Saved Positions on Home')));
  }

  AnalysisSession _newSession(Position start, List<String> moves, int? ply) {
    final tree = AnalysisTree.withLine(start, moves);
    var current = tree.root;
    for (var i = 0; i < (ply ?? moves.length) && current.children.isNotEmpty; i++) {
      current = current.children.first;
    }
    return AnalysisSession(engine: ref.read(chessEngineProvider), tree: tree, current: current)
      ..addListener(_onChange);
  }

  static String _subtitleFor(AnalysisSource source, AnalysisSession session) {
    final root = session.tree.root.position;
    final side = root.turn == Side.white ? 'White' : 'Black';
    return switch (source) {
      AnalysisSource.scan => 'From your scan · $side to move',
      AnalysisSource.setup => 'Your position · $side to move',
      AnalysisSource.game =>
        session.current.isRoot
            ? 'From your game · start'
            : 'From your game · after ${session.current.label}',
    };
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _board.updatePosition(_gameData());
    // Once saved, moves explored are kept (checked a moment after changes).
    if (_savedId != null && !(_saveTimer?.isActive ?? false)) {
      _saveTimer = Timer(_saveDelay, () => unawaited(_writeMoves()));
    }
  }

  GameData _gameData() {
    final position = _session.position;
    final last = _session.current.move?.move;
    return GameData(
      fen: position.fen,
      lastMove: last,
      playerSide: position.isGameOver ? PlayerSide.none : PlayerSide.both,
      sideToMove: position.turn,
      validMoves: makeLegalMoves(position),
      kingSquareInCheck: position.isCheck ? position.board.kingOf(position.turn) : null,
    );
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (!_session.play(move)) _board.updatePosition(_gameData());
  }

  void _flip() => setState(() => _orientation = _orientation.opposite);

  /// Opens [location] on top, with Stockfish free for that screen meanwhile.
  Future<T?> _pushAway<T>(String location, {Object? extra}) async {
    final session = _session..pause();
    final result = await context.push<T>(location, extra: extra);
    if (mounted && session == _session) session.start();
    return result;
  }

  void _askCoach() {
    final position = _session.position;
    final side = position.turn == Side.white ? 'White' : 'Black';
    _pushAway<void>(
      Routes.coachAsking(
        'What should $side play here, and why? The position (FEN): ${position.fen}',
      ),
    );
  }

  Future<void> _editPosition() async {
    final setup = await _pushAway<BoardSetup>(
      Routes.scanCheck,
      extra: ScanCheckArgs(
        setup: BoardSetup.fromFen(_session.position.fen),
        edit: true,
        returnSetup: true,
      ),
    );
    if (setup == null || !mounted) return;
    final Position start;
    try {
      start = Chess.fromSetup(Setup.parseFen(setup.fen));
    } on PositionSetupException {
      return;
    }
    final old = _session;
    await _writeMoves();
    if (!mounted) return;
    setState(() {
      _session = _newSession(start, const [], null);
      // A new start position: the saved one stays as it was; this one can be
      // saved on its own.
      _savedId = null;
      _savedState = null;
      _saveTimer?.cancel();
      _subtitle = _subtitleFor(AnalysisSource.setup, _session);
    });
    old
      ..removeListener(_onChange)
      ..dispose();
    _board.updatePosition(_gameData());
    _session.start();
  }

  Future<void> _copyFen() async {
    await Clipboard.setData(ClipboardData(text: _session.position.fen));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FEN copied')));
  }

  Future<void> _sharePosition() async {
    final png = await capturePng(_boardKey, width: 1080);
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await ref
        .read(imageSharerProvider)
        .sharePng(
          png,
          fileName: 'movewise-position.png',
          origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        );
  }

  void _playFromHere() => _pushAway<void>(Routes.playFrom(_session.position.fen));

  Future<void> _showActions() async {
    final colors = context.colors;
    final over = _session.position.isGameOver;
    final actions = <(IconData, String, VoidCallback, Color?)>[
      (
        Icons.chat_bubble_outline_rounded,
        'Ask AI Coach about this position',
        _askCoach,
        colors.brass,
      ),
      if (_savedId == null) (Icons.bookmark_add_outlined, 'Save position', _save, null),
      if (!over) (Icons.smart_toy_outlined, 'Play from here vs Stockfish', _playFromHere, null),
      (Icons.swap_vert_rounded, 'Flip board', _flip, null),
      (Icons.edit_outlined, 'Edit position', _editPosition, null),
      (Icons.content_copy_rounded, 'Copy FEN', _copyFen, null),
      (Icons.ios_share, 'Share position image', _sharePosition, null),
    ];
    final chosen = await showMoveWiseSheet<VoidCallback>(
      context,
      reduceMotion: shouldReduceMotion(context, ref),
      // ListTiles paint their ink on a Material, not on the sheet's box.
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('This position', style: context.type.heading),
            ),
            for (final (icon, label, action, colour) in actions)
              ListTile(
                minTileHeight: 52,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(icon, size: 20, color: colour ?? context.colors.textPrimary),
                title: Text(
                  label,
                  style: context.type.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colour ?? context.colors.textPrimary,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ),
    );
    chosen?.call();
  }

  Future<void> _variationMenu(AnalysisNode node, Offset at) async {
    final colors = context.colors;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    unawaited(HapticFeedback.selectionClick());
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      color: colors.bgRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            'LINE FROM ${node.label}'.toUpperCase(),
            style: context.type.overline.copyWith(color: colors.textTertiary),
          ),
        ),
        if (!node.isMainLine)
          const PopupMenuItem(
            value: 'promote',
            child: ListTile(
              leading: Icon(Icons.arrow_upward_rounded),
              title: Text('Promote to main line'),
            ),
          ),
        const PopupMenuItem(
          value: 'copy',
          child: ListTile(leading: Icon(Icons.content_copy_rounded), title: Text('Copy line')),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: colors.coral),
            title: Text('Delete from here', style: TextStyle(color: colors.coral)),
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'promote':
        _session.promote(node);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: _session.tree.lineText(node)));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Line copied')));
        }
      case 'delete':
        _session.delete(node);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = _session;
    final position = session.position;
    final analysis = session.analysis;
    final best = analysis?.lines.firstOrNull;
    final eval = analysis?.evalOf(position);
    final review = session.reviewOf(session.current);
    final wdl = best?.wdl == null ? null : whiteWdl(best!.wdl!, position.turn);

    final shapes = <Shape>{};
    if (session.engineOn &&
        best != null &&
        (analysis?.depth ?? 0) >= AnalysisSession.trustedDepth) {
      if (Move.parse(best.move) case final NormalMove move) {
        shapes.add(
          Arrow(color: colors.focus.withValues(alpha: 0.85), orig: move.from, dest: move.to),
        );
      }
    }
    if (session.threat case final threat?) {
      if (Move.parse(threat.move) case final NormalMove move) {
        shapes.add(
          Arrow(
            color: colors.coral.withValues(alpha: 0.7),
            orig: move.from,
            dest: move.to,
            scale: 0.7,
          ),
        );
      }
    }
    final quality = review?.quality;
    final node = session.current;
    if (quality != null && !node.isRoot) {
      if (landingSquare(node.before, node.move!.move) case final square?) {
        shapes.add(
          CustomShape(
            orig: square,
            child: Align(
              alignment: Alignment.topRight,
              child: _Pop(child: QualityDisc(quality: quality, size: 16)),
            ),
          ),
        );
      }
    }
    final showFeedback = quality != null && quality.isError;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The board fills the width, leaving room for the panels below.
            final boardSize = math.min(constraints.maxWidth, constraints.maxHeight - 320);
            return Column(
              children: [
                _Header(
                  subtitle: _subtitle,
                  onAskCoach: _askCoach,
                  saved: _savedId != null,
                  onSave: _save,
                  onFlip: _flip,
                  onMore: _showActions,
                ),
                EvalBar(
                  eval: session.engineOn ? eval : null,
                  toMove: position.turn,
                  orientation: _orientation,
                  signed: true,
                ),
                WdlStrip(wdl: session.engineOn ? wdl : null),
                RepaintBoundary(
                  key: _boardKey,
                  child: MoveWiseBoard(
                    controller: _board,
                    orientation: _orientation,
                    size: math.max(boardSize, 200),
                    shapes: shapes,
                    onMove: _onMove,
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: shouldReduceMotion(context, ref) ? 150 : 240),
                  child: showFeedback
                      ? MoveFeedbackCard(
                          key: ValueKey(node),
                          node: node,
                          review: review!,
                          session: session,
                        )
                      : AnalysisStatusRow(key: const ValueKey('status'), session: session),
                ),
                if (showFeedback) const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      EngineLinesCard(session: session, viewer: _orientation),
                      AnalysisMoveList(
                        session: session,
                        emptyText:
                            'Position from ${widget.args.source == AnalysisSource.scan ? 'scan' : 'setup'} · '
                            '${position.turn == Side.white ? 'White' : 'Black'} to move',
                        onLongPress: _variationMenu,
                      ),
                    ],
                  ),
                ),
                AnalysisNavBar(session: session),
              ],
            );
          },
        ),
      ),
      backgroundColor: colors.bgBase,
    );
  }
}

/// The quality chip pops onto the square (0.6 → 1) after the move lands.
class _Pop extends ConsumerWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shouldReduceMotion(context, ref)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.subtitle,
    required this.onAskCoach,
    required this.saved,
    required this.onSave,
    required this.onFlip,
    required this.onMore,
  });

  final String subtitle;
  final VoidCallback onAskCoach;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onFlip;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: Row(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysis', style: type.heading.copyWith(height: 22 / 17)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ask AI Coach about this position',
              color: colors.brass,
              onPressed: onAskCoach,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
            ),
            IconButton(
              tooltip: saved ? 'Saved' : 'Save position',
              isSelected: saved,
              color: saved ? colors.focus : null,
              onPressed: onSave,
              icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 22),
            ),
            IconButton(
              tooltip: 'Flip board',
              onPressed: onFlip,
              icon: const Icon(Icons.swap_vert_rounded, size: 22),
            ),
            IconButton(
              tooltip: 'More actions',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
            const SizedBox(width: AppSpacing.s1),
          ],
        ),
      ),
    );
  }
}
