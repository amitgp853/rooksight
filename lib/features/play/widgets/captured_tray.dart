import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The pieces a player has captured, plus their material lead ("+3").
class CapturedTray extends StatelessWidget {
  const CapturedTray({
    super.key,
    required this.captured,
    required this.capturedSide,
    this.advantage = 0,
    this.advantageColor,
  });

  /// Roles captured, most valuable first.
  final List<Role> captured;

  /// Colour of the captured pieces (the opponent's).
  final Side capturedSide;

  /// Shown when positive.
  final int advantage;

  /// Defaults to the secondary text colour.
  final Color? advantageColor;

  static const _pieceSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colour = capturedSide == Side.white ? 'w' : 'b';
    return SizedBox(
      height: _pieceSize,
      child: Row(
        children: [
          for (final role in captured)
            Align(
              widthFactor: 0.7, // Overlap like a stack of pieces.
              child: Image.asset(
                'assets/pieces/$colour${role.uppercaseLetter}.png',
                width: _pieceSize,
                height: _pieceSize,
              ),
            ),
          if (advantage > 0) ...[
            const SizedBox(width: 6),
            Text(
              '+$advantage',
              style: context.type.mono.copyWith(
                fontSize: 12,
                color: advantageColor ?? context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
