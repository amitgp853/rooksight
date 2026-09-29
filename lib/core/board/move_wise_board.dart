import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion/reduce_motion.dart';
import '../settings/display_settings.dart';
import '../theme/app_theme.dart';
import '../theme/board_themes.dart';
import 'board_style.dart';

/// Interactive board in the MoveWise style. Fills the available width, edge to
/// edge (boards ignore the screen gutter).
class MoveWiseBoard extends ConsumerWidget {
  const MoveWiseBoard({
    super.key,
    required this.controller,
    required this.orientation,
    this.size,
    this.onMove,
    this.onTouchedSquare,
    this.shapes = const {},
    this.annotations = const {},
    this.pieceOrientation = PieceOrientationBehavior.facingUser,
  });

  final ChessboardController controller;

  /// Defaults to the available width.
  final double? size;
  final Side orientation;
  final void Function(Move move, {bool? viaDragAndDrop})? onMove;

  /// Called on every touch of a square, even when it is not the user's turn.
  final void Function(Square square)? onTouchedSquare;
  final Set<Shape> shapes;
  final Map<Square, Annotation> annotations;

  /// Which way the pieces face; over-the-board play turns them.
  final PieceOrientationBehavior pieceOrientation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = moveWiseBoardSettings(
      theme: ref.watch(boardThemeProvider),
      colors: context.colors,
      reduceMotion: shouldReduceMotion(context, ref),
    ).copyWith(pieceOrientationBehavior: pieceOrientation);
    Widget board(double size) => Chessboard(
      size: size,
      controller: controller,
      settings: settings,
      orientation: orientation,
      onMove: onMove,
      onTouchedSquare: onTouchedSquare,
      shapes: shapes,
      annotations: annotations,
    );

    final size = this.size;
    if (size != null) return board(size);
    return LayoutBuilder(builder: (context, constraints) => board(constraints.maxWidth));
  }
}

/// Non-interactive board, for thumbnails, review positions and report cards.
class MoveWiseStaticBoard extends ConsumerWidget {
  const MoveWiseStaticBoard({
    super.key,
    required this.fen,
    this.size,
    this.orientation = Side.white,
    this.lastMove,
    this.shapes = const {},
    this.coordinates = true,
    this.borderRadius = BorderRadius.zero,
    this.theme,
  });

  final String fen;

  /// Defaults to the available width.
  final double? size;
  final Side orientation;
  final Move? lastMove;
  final Set<Shape> shapes;
  final bool coordinates;
  final BorderRadiusGeometry borderRadius;

  /// Overrides the board theme from settings (e.g. for theme previews).
  final BoardTheme? theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = moveWiseBoardSettings(
      theme: theme ?? ref.watch(boardThemeProvider),
      colors: context.colors,
      reduceMotion: shouldReduceMotion(context, ref),
    );
    final settings = StaticChessboardSettings.fromBoardSettings(
      base,
    ).copyWith(enableCoordinates: coordinates, borderRadius: borderRadius);

    Widget board(double size) => StaticChessboard(
      size: size,
      fen: fen,
      orientation: orientation,
      lastMove: lastMove,
      shapes: shapes,
      settings: settings,
    );

    final size = this.size;
    if (size != null) return board(size);
    return LayoutBuilder(builder: (context, constraints) => board(constraints.maxWidth));
  }
}
