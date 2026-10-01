import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/reduce_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../analysis/domain/analysis_args.dart';
import 'domain/board_reader.dart';
import 'domain/board_setup.dart';
import 'domain/position_check.dart';
import 'widgets/piece_palette.dart';
import 'widgets/setup_board.dart';

/// What the check screen opens on.
@immutable
class ScanCheckArgs {
  const ScanCheckArgs({
    this.result,
    this.photo,
    this.setup,
    this.edit = false,
    this.returnSetup = false,
  });

  /// What a scan read; null when setting up by hand.
  final ScanResult? result;

  /// The cropped photo, to compare against.
  final Uint8List? photo;

  /// A position to start from when there's no [result] (empty if null).
  final BoardSetup? setup;

  /// Opens in edit mode.
  final bool edit;

  /// "Analyze" pops with the [BoardSetup] instead of opening the analysis
  /// board (editing the analysis board's own position).
  final bool returnSetup;
}

/// Check the position (`ScanConfirm*.dc.html`): the scan's reading on a
/// board, squares it was unsure of marked, an editor to fix any square, and
/// what a photo can't show (side to move, castling, which side is at the
/// bottom). Analyze stays off until the position is legal.
class ScanCheckScreen extends ConsumerStatefulWidget {
  const ScanCheckScreen({super.key, this.args = const ScanCheckArgs(edit: true)});

  final ScanCheckArgs args;

  @override
  ConsumerState<ScanCheckScreen> createState() => _ScanCheckScreenState();
}

class _ScanCheckScreenState extends ConsumerState<ScanCheckScreen> {
  late final BoardSetup _detected =
      widget.args.result?.setup ?? widget.args.setup ?? BoardSetup.empty();
  late BoardSetup _setup = _detected;
  late Set<Square> _unsure = {...?widget.args.result?.unsure};
  late bool _whiteAtBottom = widget.args.result?.whiteAtBottom ?? true;
  late bool _editing = widget.args.edit || widget.args.result == null;
  bool _comparing = false;

  /// While editing: the photo stands in for the board (tap the thumbnail),
  /// so squares can be checked against it and still be picked.
  bool _photoOnBoard = false;

  /// The square being edited. Tapping the board only ever selects; the
  /// palette then sets what's on the selected square.
  Square? _selected;

  Uint8List? get _photo => widget.args.photo;
  bool get _fromScan => widget.args.result != null;

  void _change(VoidCallback change) => setState(change);

  void _place(Square square, Piece? piece) {
    _setup = _setup.withPiece(square, piece);
    _unsure = {..._unsure}..remove(square);
  }

  void _onTapSquare(Square square) => _change(() {
    if (_comparing) {
      _comparing = false;
      return;
    }
    if (!_editing) {
      // Tap a doubtful square to fix it: straight into the editor.
      _editing = true;
      _selected = square;
      return;
    }
    // Select, or tap the selected square again to let it go. Never changes
    // a piece.
    _selected = _selected == square ? null : square;
  });

  /// Puts [choice] on the selected square (the eraser empties it). The
  /// square stays selected, so another choice simply replaces it.
  void _onPick(PaletteChoice choice) => _change(() {
    if (_selected case final square?) _place(square, choice.piece);
  });

  void _flipSides(bool whiteAtBottom) => _change(() {
    if (whiteAtBottom == _whiteAtBottom) return;
    _whiteAtBottom = whiteAtBottom;
    _setup = _setup.rotated();
    _unsure = {for (final s in _unsure) Square(63 - s)};
    if (_selected case final s?) _selected = Square(63 - s);
  });

  void _analyze(BoardSetup setup) {
    if (widget.args.returnSetup) {
      context.pop(setup);
      return;
    }
    context.push(
      AnalysisArgs(
        fen: setup.fen,
        source: _fromScan ? AnalysisSource.scan : AnalysisSource.setup,
        orientation: _whiteAtBottom ? Side.white : Side.black,
      ).location,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final problem = checkPosition(_setup);
    final reduce = shouldReduceMotion(context, ref);

    return PopScope(
      canPop: !_comparing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _comparing) setState(() => _comparing = false);
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardSize = math.min(constraints.maxWidth, 520.0);
              return Column(
                children: [
                  _Header(
                    title: _editing ? 'Edit position' : 'Check the position',
                    subtitle: _editing
                        ? 'Changes stay on this phone'
                        : 'Then set what a photo can’t show',
                    editing: _editing,
                    onBack: () => _comparing
                        ? setState(() => _comparing = false)
                        : Navigator.of(context).maybePop(),
                    onEdit: () => _change(() {
                      _editing = !_editing;
                      _comparing = false;
                      _photoOnBoard = false;
                      if (!_editing) _selected = null;
                    }),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Banner(
                            state: _bannerState(problem),
                            photo: _comparing ? null : _photo,
                            photoShown: _editing && _photoOnBoard,
                            onPhoto: () => setState(() {
                              // Editing: swap board and photo in place.
                              // Checking: the side-by-side comparison.
                              if (_editing) {
                                _photoOnBoard = !_photoOnBoard;
                              } else {
                                _comparing = true;
                              }
                            }),
                          ),
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: reduce ? 150 : 200),
                            child: _comparing && _photo != null
                                ? _Compare(
                                    key: const ValueKey('compare'),
                                    photo: _photo!,
                                    setup: _setup,
                                    unsure: _unsure,
                                    onClose: () => setState(() => _comparing = false),
                                  )
                                : _editing && _photoOnBoard && _photo != null
                                ? Center(
                                    key: const ValueKey('photo'),
                                    child: _PhotoBoard(
                                      photo: _photo!,
                                      size: boardSize,
                                      // The setup shows White at the bottom.
                                      turned: !_whiteAtBottom,
                                      unsure: _unsure,
                                      selected: _selected,
                                      onTap: _onTapSquare,
                                    ),
                                  )
                                : Center(
                                    key: const ValueKey('board'),
                                    child: SetupBoard(
                                      board: _setup.board,
                                      size: boardSize,
                                      unsure: _unsure,
                                      problems: problem?.squares ?? const {},
                                      selected: _editing ? _selected : null,
                                      onTap: _onTapSquare,
                                    ),
                                  ),
                          ),
                          if (_editing)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                              child: Column(
                                spacing: AppSpacing.s2,
                                children: [
                                  PiecePalette(
                                    // What the selected square holds; nothing
                                    // to pick until a square is selected.
                                    selected: _selected == null
                                        ? null
                                        : (piece: _setup.pieceAt(_selected!)),
                                    onSelect: _selected == null ? null : _onPick,
                                  ),
                                  Text(
                                    _selected == null
                                        ? 'Tap a square first, then choose its piece.'
                                        : 'Choose the piece for ${_selected!.name}, or the eraser to '
                                              'empty it. Tap another square to move on.',
                                    textAlign: TextAlign.center,
                                    style: type.label.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (!_comparing)
                            _Details(
                              setup: _setup,
                              whiteAtBottom: _whiteAtBottom,
                              onTurn: (side) => _change(() => _setup = _setup.copyWith(turn: side)),
                              onCastling: (right, allowed) => _change(
                                () => _setup = _setup.withCastling(right, allowed: allowed),
                              ),
                              onWhiteAtBottom: _flipSides,
                            ),
                          const SizedBox(height: AppSpacing.s3),
                        ],
                      ),
                    ),
                  ),
                  _Footer(
                    problem: problem,
                    canReset: _setup != _detected,
                    canClear: !_setup.isEmpty,
                    resetLabel: _fromScan ? 'Reset to detected' : 'Reset',
                    onClear: () => _change(() {
                      _setup = _setup.copyWith(pieces: const {});
                      _unsure = {};
                      _editing = true;
                    }),
                    onReset: () => _change(() {
                      _setup = _detected;
                      _unsure = {...?widget.args.result?.unsure};
                      _whiteAtBottom = widget.args.result?.whiteAtBottom ?? true;
                    }),
                    onAnalyze: problem == null ? () => _analyze(_setup) : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  _BannerState _bannerState(PositionProblem? problem) {
    if (problem != null && !_setup.isEmpty) return _BannerState.problem(problem.message);
    if (_editing) {
      if (_photoOnBoard && _photo != null) {
        return const _BannerState.editing(
          'Your photo, lined up with the board. Tap a square on it, then choose its piece.',
        );
      }
      return _BannerState.editing(
        'Editing. Tap a square, then choose its piece below.'
        '${_photo != null ? ' Tap the photo to compare.' : ''}',
      );
    }
    final unsure = [for (final s in _unsure) s.name]..sort();
    if (_comparing) {
      return _BannerState.unsure(
        unsure.isEmpty
            ? 'Compare the board with your photo.'
            : 'Check the ${unsure.length == 1 ? 'square' : '${_count(unsure.length)} squares'} '
                  'against your photo.',
      );
    }
    if (unsure.isNotEmpty) {
      final list = unsure.length == 1
          ? unsure.single
          : '${unsure.sublist(0, unsure.length - 1).join(', ')} and ${unsure.last}';
      return _BannerState.unsure(
        '${unsure.length} ${unsure.length == 1 ? 'square' : 'squares'} to check: $list.'
        '${_photo != null ? ' Tap the photo to compare.' : ''}',
      );
    }
    return const _BannerState.ok('Looks right? Set the details below, then Analyze.');
  }

  static String _count(int n) => switch (n) {
    2 => 'two',
    3 => 'three',
    _ => '$n',
  };
}

enum _BannerKind { problem, editing, unsure, ok }

class _BannerState {
  const _BannerState.problem(this.text) : kind = _BannerKind.problem;
  const _BannerState.editing(this.text) : kind = _BannerKind.editing;
  const _BannerState.unsure(this.text) : kind = _BannerKind.unsure;
  const _BannerState.ok(this.text) : kind = _BannerKind.ok;

  final _BannerKind kind;
  final String text;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.editing,
    required this.onBack,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
        child: Row(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: type.heading.copyWith(height: 22 / 17)),
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
            Semantics(
              toggled: editing,
              child: editing
                  ? FilledButton.icon(
                      onPressed: onEdit,
                      style: _pillStyle(context),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Done'),
                    )
                  : OutlinedButton.icon(
                      onPressed: onEdit,
                      style: _pillStyle(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static ButtonStyle _pillStyle(BuildContext context) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
    fixedSize: const WidgetStatePropertyAll(Size.fromHeight(36)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    textStyle: WidgetStatePropertyAll(
      context.type.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// The line above the board: what to check, what's wrong, or that it's fine.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.state,
    required this.photo,
    required this.onPhoto,
    this.photoShown = false,
  });

  final _BannerState state;
  final Uint8List? photo;
  final VoidCallback onPhoto;

  /// The photo is on the board: its thumbnail is ringed, and tapping it
  /// brings the board back.
  final bool photoShown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (tint, dot, dotFg, symbol) = switch (state.kind) {
      _BannerKind.problem => (colors.coral, colors.coral, _Ink.ink, '!'),
      _BannerKind.editing => (null, colors.focus, colors.onFocus, '✎'),
      _BannerKind.unsure => (colors.brass, const Color(0xFFE3B25C), _Ink.brassInk, '?'),
      _BannerKind.ok => (colors.focus, colors.focus, colors.onFocus, '✓'),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: tint == null ? colors.bgRaised : tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint == null ? colors.border : tint.withValues(alpha: 0.45)),
        ),
        child: Row(
          spacing: 10,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    symbol,
                    style: context.type.heading.copyWith(
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: dotFg,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                state.text,
                style: context.type.label.copyWith(fontWeight: FontWeight.w400, height: 18 / 13),
              ),
            ),
            if (photo != null)
              Semantics(
                // Its own node: a button, not part of the banner's text.
                container: true,
                button: true,
                toggled: photoShown,
                label: photoShown ? 'Show the board' : 'Compare with your photo',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onPhoto,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 40,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: photoShown ? colors.focus : colors.border,
                        width: photoShown ? 2 : 1.5,
                      ),
                    ),
                    child: Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ink colours on the brass and coral dots, the same in both themes.
abstract final class _Ink {
  static const ink = Color(0xFF0B1224);
  static const brassInk = Color(0xFF1A1204);
}

/// The photo in the board's place while editing, lined up square for square:
/// a faint grid, the selected square ringed, and taps pick squares.
class _PhotoBoard extends StatelessWidget {
  const _PhotoBoard({
    required this.photo,
    required this.size,
    required this.turned,
    required this.unsure,
    required this.selected,
    required this.onTap,
  });

  final Uint8List photo;
  final double size;

  /// Taken from Black's side: shown upside down so it matches the board.
  final bool turned;
  final Set<Square> unsure;
  final Square? selected;
  final ValueChanged<Square> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cell = size / 8;
    Widget ring(Square s, Color color) => Positioned(
      left: s.file * cell,
      top: (7 - s.rank) * cell,
      width: cell,
      height: cell,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return Semantics(
      label: 'Your photo, in place of the board',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final pos = details.localPosition;
          final file = (pos.dx / cell).floor().clamp(0, 7);
          final rank = 7 - (pos.dy / cell).floor().clamp(0, 7);
          onTap(Square.fromCoords(File(file), Rank(rank)));
        },
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: RotatedBox(
                  quarterTurns: turned ? 2 : 0,
                  child: Image.memory(photo, fit: BoxFit.fill, gaplessPlayback: true),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
              ),
              for (final s in unsure)
                if (s != selected) ring(s, colors.brass),
              if (selected case final s?) ring(s, colors.focus),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint lines between the squares, so the photo reads as a board.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x59F5F7FA)
      ..strokeWidth = 1;
    final cell = size.width / 8;
    for (var i = 1; i < 8; i++) {
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), paint)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// The photo and the board side by side.
class _Compare extends StatelessWidget {
  const _Compare({
    super.key,
    required this.photo,
    required this.setup,
    required this.unsure,
    required this.onClose,
  });

  final Uint8List photo;
  final BoardSetup setup;
  final Set<Square> unsure;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = context.type.label.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.maxWidth - 8) / 2;
          return Column(
            spacing: AppSpacing.s2,
            children: [
              Row(
                spacing: 8,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        photo,
                        width: side,
                        height: side,
                        fit: BoxFit.cover,
                        semanticLabel: 'Your photo',
                      ),
                    ),
                  ),
                  SetupBoard(
                    board: setup.board,
                    size: side,
                    unsure: unsure,
                    coordinates: false,
                    borderRadius: BorderRadius.circular(10),
                    onTap: (_) => onClose(),
                  ),
                ],
              ),
              Row(
                spacing: 8,
                children: [
                  SizedBox(
                    width: side,
                    child: Text('Your photo', textAlign: TextAlign.center, style: caption),
                  ),
                  SizedBox(
                    width: side,
                    child: Text('What MoveWise saw', textAlign: TextAlign.center, style: caption),
                  ),
                ],
              ),
              Text(
                unsure.isEmpty
                    ? 'Tap either one to go back and fix a square.'
                    : 'Squares marked “?” are the ones the scan was least sure about. '
                          'Tap either one to go back and fix them.',
                textAlign: TextAlign.center,
                style: context.type.label.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 19 / 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Side to move, castling, and which side was at the bottom of the photo.
class _Details extends StatelessWidget {
  const _Details({
    required this.setup,
    required this.whiteAtBottom,
    required this.onTurn,
    required this.onCastling,
    required this.onWhiteAtBottom,
  });

  final BoardSetup setup;
  final bool whiteAtBottom;
  final ValueChanged<Side> onTurn;
  final void Function(CastlingRight right, bool allowed) onCastling;
  final ValueChanged<bool> onWhiteAtBottom;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final light = Theme.of(context).brightness == Brightness.light;
    final rowText = type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
    final divider = Divider(height: 1, thickness: 1, color: colors.bgElevated);

    Widget turnButton(Side side) {
      final on = setup.turn == side;
      return Expanded(
        child: Semantics(
          selected: on,
          inMutuallyExclusiveGroup: true,
          button: true,
          child: Material(
            color: on ? (light ? colors.bgRaised : const Color(0xFF2A3A5E)) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            elevation: on && light ? 1 : 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onTurn(side),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 6,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: side == Side.white
                            ? const Color(0xFFF5F7FA)
                            : const Color(0xFF1E2530),
                        border: Border.all(
                          color: side == Side.white
                              ? const Color(0xFF1A212B)
                              : const Color(0x80E2E8F0),
                        ),
                      ),
                    ),
                    Text(
                      side == Side.white ? 'White' : 'Black',
                      style: type.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: on ? colors.textPrimary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget castleChip(CastlingRight right) {
      final possible = setup.canCastle(right);
      final on = possible && setup.castling.contains(right);
      final label = right.wing == CastlingSide.king ? 'O-O' : 'O-O-O';
      final side = right.side == Side.white ? 'White' : 'Black';
      return Semantics(
        checked: on,
        enabled: possible,
        label: '$side ${right.wing == CastlingSide.king ? 'kingside' : 'queenside'}',
        excludeSemantics: true,
        child: Opacity(
          opacity: possible ? 1 : 0.45,
          child: Material(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: possible ? () => onCastling(right, !on) : null,
              child: Container(
                height: 44,
                padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: on ? colors.focus : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: on ? null : Border.all(color: colors.border, width: 1.5),
                      ),
                      child: on ? Icon(Icons.check_rounded, size: 14, color: colors.onFocus) : null,
                    ),
                    Text(label, style: type.mono.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bgRaised,
        borderRadius: AppRadius.mdAll,
        border: light ? Border.all(color: colors.border) : null,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: Text('Side to move', style: rowText)),
                Container(
                  width: 176,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.bgBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    spacing: 3,
                    children: [turnButton(Side.white), turnButton(Side.black)],
                  ),
                ),
              ],
            ),
          ),
          for (final side in Side.values) ...[
            divider,
            SizedBox(
              height: 52,
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      '${side == Side.white ? 'White' : 'Black'} can castle',
                      style: rowText,
                    ),
                  ),
                  castleChip((side: side, wing: CastlingSide.king)),
                  castleChip((side: side, wing: CastlingSide.queen)),
                ],
              ),
            ),
          ],
          divider,
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('White is at the bottom', style: rowText),
                        Text(
                          'Turn off if the photo was taken from Black’s side',
                          style: type.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: whiteAtBottom, onChanged: onWhiteAtBottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.problem,
    required this.canReset,
    required this.canClear,
    required this.resetLabel,
    required this.onClear,
    required this.onReset,
    required this.onAnalyze,
  });

  final PositionProblem? problem;
  final bool canReset;
  final bool canClear;
  final String resetLabel;
  final VoidCallback onClear;
  final VoidCallback onReset;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final small = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      fixedSize: const Size.fromHeight(44),
      textStyle: type.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s2,
        children: [
          Row(
            spacing: AppSpacing.s2,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: small,
                  onPressed: canClear ? onClear : null,
                  child: const Text('Clear board'),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  style: small,
                  onPressed: canReset ? onReset : null,
                  child: Text(resetLabel),
                ),
              ),
            ],
          ),
          Semantics(
            hint: problem?.message,
            child: FilledButton(
              onPressed: onAnalyze,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: type.heading,
              ),
              child: const Text('Analyze'),
            ),
          ),
        ],
      ),
    );
  }
}
