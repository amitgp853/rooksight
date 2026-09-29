import 'package:flutter/painting.dart';

/// Board colour themes, used by the board and the Settings theme picker.
enum BoardTheme {
  slate(
    label: 'Slate',
    lightSquare: Color(0xFFCDD5E0),
    darkSquare: Color(0xFF6B7C94),
    lastMoveLight: Color(0xFFE8D9A4),
    lastMoveDark: Color(0xFFB39962),
    lastMoveOverlay: Color(0x6BFFD037),
  ),
  ink(
    label: 'Ink',
    lightSquare: Color(0xFFD9DEE5),
    darkSquare: Color(0xFF46536B),
    lastMoveLight: Color(0xFFE8D9A4),
    lastMoveDark: Color(0xFF8F7C52),
    lastMoveOverlay: Color(0x61FFC832),
  ),
  dusk(
    label: 'Dusk',
    lightSquare: Color(0xFFDED7E9),
    darkSquare: Color(0xFF7C6E9B),
    lastMoveLight: Color(0xFFECDDB2),
    lastMoveDark: Color(0xFFA88E74),
    lastMoveOverlay: Color(0x4FFFE02A),
  ),
  ember(
    label: 'Ember',
    lightSquare: Color(0xFFEEDFCF),
    darkSquare: Color(0xFFB47A5E),
    lastMoveLight: Color(0xFFF0DC9E),
    lastMoveDark: Color(0xFFC49A55),
    lastMoveOverlay: Color(0x52EDDA3C),
  );

  const BoardTheme({
    required this.label,
    required this.lightSquare,
    required this.darkSquare,
    required this.lastMoveLight,
    required this.lastMoveDark,
    required this.lastMoveOverlay,
  });

  final String label;
  final Color lightSquare;
  final Color darkSquare;

  /// Brass last-move tint on light / dark squares, as designed.
  final Color lastMoveLight;
  final Color lastMoveDark;

  /// chessground highlights both squares of the last move with one colour, so
  /// this translucent brass is fitted to land on [lastMoveLight] and
  /// [lastMoveDark] when drawn over each square colour (within a few 1/255s).
  final Color lastMoveOverlay;
}
