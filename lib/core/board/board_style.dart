// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';
import '../theme/board_themes.dart';

/// The Rooksight piece set, rendered from `design/pieces/` by
/// `tool/render_pieces.dart`.
final PieceAssets rooksightPieceAssets = {
  for (final kind in PieceKind.values)
    kind: AssetImage(
      'assets/pieces/${kind.side == Side.white ? 'w' : 'b'}${kind.role.uppercaseLetter}.png',
    ),
};

/// Loads the piece images into chessground's cache so the first board
/// renders without pieces popping in.
Future<void> precachePieces() {
  final dpr = WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1.0;
  return ChessgroundImages.instance.loadAll(rooksightPieceAssets, devicePixelRatio: dpr);
}

/// Hint arrow: brass at 92%, shaft 20% of a square (chessground's 1.0 is 25%).
Arrow hintArrow(AppColors colors, {required Square from, required Square to}) {
  return Arrow(color: colors.brass.withValues(alpha: 0.92), orig: from, dest: to, scale: 0.8);
}

/// How long a moved piece slides to its square (motion spec: MOVE).
const moveSlide = Duration(milliseconds: 200);

/// Board settings matching the design (`design/design-spec.md` > Board and
/// Motion). Where chessground can't match the spec, it uses the closest
/// setting; the gaps are listed in the Phase 1 plan.
ChessboardSettings rooksightBoardSettings({
  required BoardTheme theme,
  required AppColors colors,
  required bool reduceMotion,
  bool premoves = false,
}) {
  return ChessboardSettings(
    colorScheme: _colorScheme(theme, colors),
    pieceAssets: rooksightPieceAssets,
    enableCoordinates: true,
    // Moves slide in 200ms. With reduced motion nothing travels; chessground
    // can't crossfade, so moves are instant.
    animationDuration: reduceMotion ? Duration.zero : moveSlide,
    // Lift to 1.1x and ride 0.4 square above the finger. Reduced motion: no
    // scale-up (chessground then centres the piece under the finger).
    dragFeedbackScale: reduceMotion ? 1.0 : _dragScale,
    dragFeedbackOffset: const Offset(0, -0.8 / _dragScale),
    dragTargetKind: DragTargetKind.square,
    // Only games against Stockfish allow premoves. A promotion premove
    // becomes a queen, as on Lichess.
    enablePremoves: premoves,
    drawShape: const DrawShapeOptions(enable: false),
  );
}

const _dragScale = 1.1;

ChessboardColorScheme _colorScheme(BoardTheme theme, AppColors colors) {
  SolidColorChessboardBackground background({bool coordinates = false, Side side = Side.white}) =>
      SolidColorChessboardBackground(
        lightSquare: theme.lightSquare,
        darkSquare: theme.darkSquare,
        coordinates: coordinates,
        orientation: side,
      );

  return ChessboardColorScheme(
    lightSquare: theme.lightSquare,
    darkSquare: theme.darkSquare,
    background: background(),
    whiteCoordBackground: background(coordinates: true),
    blackCoordBackground: background(coordinates: true, side: Side.black),
    lastMove: HighlightDetails(solidColor: theme.lastMoveOverlay),
    selected: HighlightDetails(solidColor: colors.focus.withValues(alpha: 0.55)),
    // Legal-move dots and capture rings: rgba(14, 18, 23, 0.32).
    validMoves: const Color(0x520E1217),
    // The queued premove's squares and the premove dots: the focus blue, so
    // they read apart from the last move and the legal-move dots.
    validPremoves: colors.focus.withValues(alpha: 0.4),
  );
}
