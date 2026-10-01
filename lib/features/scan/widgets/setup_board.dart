import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/board/rooksight_board.dart';
import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A board being set up: White at the bottom, tap a square to change it.
/// Squares the scan was unsure of get a brass ring and a "?", squares behind
/// a rule the position breaks a coral ring, the selected one a blue ring.
class SetupBoard extends ConsumerWidget {
  const SetupBoard({
    super.key,
    required this.board,
    required this.size,
    this.unsure = const {},
    this.problems = const {},
    this.selected,
    this.onTap,
    this.coordinates = true,
    this.borderRadius = BorderRadius.zero,
  });

  final Board board;
  final double size;
  final Set<Square> unsure;
  final Set<Square> problems;
  final Square? selected;
  final ValueChanged<Square>? onTap;
  final bool coordinates;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final reduce = shouldReduceMotion(context, ref);
    final square = size / 8;

    Widget ring(Color color, {bool mark = false}) => Stack(
      fit: StackFit.expand,
      children: [
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (mark)
          Align(
            alignment: Alignment.topRight,
            child: Container(
              width: square * 0.36,
              height: square * 0.36,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '?',
                  style: context.type.heading.copyWith(
                    fontSize: square * 0.22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1204),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final shapes = <Shape>{
      for (final s in unsure.difference(problems))
        CustomShape(
          orig: s,
          // Rings fade in after the board appears (design: 200ms, delay 150).
          child: _FadeIn(reduce: reduce, child: ring(colors.brass, mark: true)),
        ),
      for (final s in problems) CustomShape(orig: s, child: ring(colors.coral)),
      if (selected case final s? when !problems.contains(s))
        CustomShape(orig: s, child: ring(colors.focus)),
    };

    return Semantics(
      label: 'Board',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onTap == null
            ? null
            : (details) {
                final pos = details.localPosition;
                final file = (pos.dx / square).floor().clamp(0, 7);
                final rank = 7 - (pos.dy / square).floor().clamp(0, 7);
                onTap!(Square.fromCoords(File(file), Rank(rank)));
              },
        child: RooksightStaticBoard(
          fen: board.fen,
          size: size,
          shapes: shapes,
          coordinates: coordinates,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.reduce, required this.child});

  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: const Interval(150 / 350, 1),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
