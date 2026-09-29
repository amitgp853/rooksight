import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A rounded square in [side]'s piece colour (porcelain or ink, the same in
/// both themes), with the player's [initial] when given.
class SideChip extends StatelessWidget {
  const SideChip({super.key, required this.side, this.size = 36, this.initial});

  final Side side;
  final double size;
  final String? initial;

  // The design's piece colours: fill, outline and letter.
  static const _white = (fill: Color(0xFFF5F7FA), ring: Color(0xFF1A212B), text: Color(0xFF1A212B));
  static const _black = (fill: Color(0xFF1E2530), ring: Color(0x73E2E8F0), text: Color(0xFFE9EDF2));

  @override
  Widget build(BuildContext context) {
    final palette = side == Side.white ? _white : _black;
    final initial = this.initial;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: palette.ring),
      ),
      child: initial == null
          ? null
          : Text(
              initial,
              style: context.type.heading.copyWith(
                fontSize: size * 0.42,
                height: 1,
                color: palette.text,
              ),
            ),
    );
  }
}

/// The first letter of [name], capitalised, for a [SideChip].
String initialOf(String name) => name.isEmpty ? '?' : name.characters.first.toUpperCase();
