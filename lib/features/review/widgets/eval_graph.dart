// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_analysis.dart';
import '../domain/move_review.dart';
import 'quality_chip.dart';

/// The evaluation over the game, from the player's side (up is good for
/// them), plotted as winning chances so huge scores don't flatten the rest.
/// Key moments are dots in their mark's colour; tap or drag to jump.
class EvalGraph extends StatelessWidget {
  const EvalGraph({
    super.key,
    required this.analysis,
    required this.player,
    required this.ply,
    required this.onSelect,
  });

  final GameAnalysis analysis;
  final Side player;

  /// The position shown on the board.
  final int ply;
  final ValueChanged<int> onSelect;

  static const height = 96.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final plies = analysis.game.history.length - 1;
    final moments = {for (final m in analysis.keyMoments(player)) m.index + 1: m.quality!};

    void select(Offset position, double width) {
      if (plies <= 0) return;
      onSelect((position.dx / width * plies).round().clamp(0, plies));
    }

    return Semantics(
      label: 'Evaluation graph',
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          onTapDown: (d) => select(d.localPosition, constraints.maxWidth),
          onHorizontalDragUpdate: (d) => select(d.localPosition, constraints.maxWidth),
          child: CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _EvalPainter(
              values: [
                for (var i = 0; i <= plies; i++)
                  switch (analysis.whiteEval(i)) {
                    final white? => winPercent(player == Side.white ? white : -white) / 100,
                    null => null,
                  },
              ],
              moments: moments,
              ply: ply,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvalPainter extends CustomPainter {
  _EvalPainter({
    required this.values,
    required this.moments,
    required this.ply,
    required this.colors,
  });

  /// Player's winning chances 0–1 per ply; null where not analysed yet.
  final List<double?> values;
  final Map<int, MoveQuality> moments;
  final int ply;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final count = values.length;
    double x(int i) => count <= 1 ? 0 : i / (count - 1) * size.width;
    double y(double v) => size.height * (1 - v);
    final middle = y(0.5);

    // Level line.
    canvas.drawLine(
      Offset(0, middle),
      Offset(size.width, middle),
      Paint()
        ..color = colors.border
        ..strokeWidth = 1,
    );

    final known = [
      for (var i = 0; i < count; i++)
        if (values[i] != null) (i, values[i]!),
    ];
    if (known.isNotEmpty) {
      final line = Path()..moveTo(x(known.first.$1), y(known.first.$2));
      for (final (i, v) in known.skip(1)) {
        line.lineTo(x(i), y(v));
      }
      final area = Path.from(line)
        ..lineTo(x(known.last.$1), middle)
        ..lineTo(x(known.first.$1), middle)
        ..close();
      canvas
        ..drawPath(area, Paint()..color = colors.focus.withValues(alpha: 0.14))
        ..drawPath(
          line,
          Paint()
            ..color = colors.focus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        );
    }

    // The position on the board.
    final cursor = x(ply.clamp(0, count - 1));
    canvas.drawLine(
      Offset(cursor, 0),
      Offset(cursor, size.height),
      Paint()
        ..color = colors.textSecondary.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    // Key moments, on the position right after the move.
    for (final MapEntry(key: i, value: quality) in moments.entries) {
      final v = i < count ? values[i] : null;
      if (v == null) continue;
      canvas
        ..drawCircle(Offset(x(i), y(v)), 5, Paint()..color = colors.bgRaised)
        ..drawCircle(Offset(x(i), y(v)), 4, Paint()..color = qualityColor(colors, quality));
    }
  }

  @override
  bool shouldRepaint(_EvalPainter old) =>
      old.values != values || old.ply != ply || old.moments != moments || old.colors != colors;
}
