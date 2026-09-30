import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';

/// What the palette places: a piece, or nothing (the eraser).
typedef PaletteChoice = ({Piece? piece});

/// The pieces to place when setting up a position (`PiecePalette.dc.html`):
/// white's six, the eraser, then black's six, in a 7-column grid.
class PiecePalette extends StatelessWidget {
  const PiecePalette({super.key, required this.selected, required this.onSelect});

  /// Null when nothing is picked yet.
  final PaletteChoice? selected;
  final ValueChanged<PaletteChoice> onSelect;

  static const _roles = [Role.king, Role.queen, Role.rook, Role.bishop, Role.knight, Role.pawn];

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (final role in _roles) _pieceTile(context, Piece(color: Side.white, role: role)),
      _tile(
        context,
        choice: (piece: null),
        label: 'Eraser: remove a piece',
        child: SvgPicture.string(
          _eraser,
          width: 22,
          height: 22,
          colorFilter: ColorFilter.mode(context.colors.textPrimary, BlendMode.srcIn),
        ),
      ),
      for (final role in _roles) _pieceTile(context, Piece(color: Side.black, role: role)),
      const SizedBox.shrink(),
    ];
    return Semantics(
      container: true,
      label: 'Piece to place',
      child: Column(
        spacing: 6,
        children: [
          for (var row = 0; row < 2; row++)
            Row(
              spacing: 6,
              children: [for (var col = 0; col < 7; col++) Expanded(child: cells[row * 7 + col])],
            ),
        ],
      ),
    );
  }

  Widget _pieceTile(BuildContext context, Piece piece) => _tile(
    context,
    choice: (piece: piece),
    label: '${piece.color == Side.white ? 'White' : 'Black'} ${piece.role.name}',
    child: Image.asset(
      'assets/pieces/${piece.color == Side.white ? 'w' : 'b'}${piece.role.uppercaseLetter}.png',
      width: 36,
      height: 36,
    ),
  );

  Widget _tile(
    BuildContext context, {
    required PaletteChoice choice,
    required String label,
    required Widget child,
  }) {
    final colors = context.colors;
    final on = selected != null && selected!.piece == choice.piece;
    return Semantics(
      label: label,
      selected: on,
      inMutuallyExclusiveGroup: true,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: on ? colors.focus.withValues(alpha: 0.16) : colors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: on ? BorderSide(color: colors.focus, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelect(choice),
          child: SizedBox(height: 46, child: Center(child: child)),
        ),
      ),
    );
  }

  static const _eraser =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.9" '
      'stroke-linecap="round" stroke-linejoin="round"><path d="M16 4l5 5-9.5 9.5H6.5L3 15l9.5-9.5zM9 8l7 7M7 20h13"/></svg>';
}
