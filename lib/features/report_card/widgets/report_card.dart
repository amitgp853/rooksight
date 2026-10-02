// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/board/rooksight_board.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/board_themes.dart';
import '../../../core/widgets/logo_mark.dart';
import '../../review/widgets/quality_chip.dart';
import '../domain/game_report.dart';

/// The shareable report card (`design/source/ReportCard.dc.html`), laid out
/// in the design's own pixels: [width] × [height]. Always dark: it's a
/// branded image, whatever the app's theme. Scale it with a `FittedBox`.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final GameReport report;

  static const width = 1080.0;
  static const height = 1350.0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(builder: _card),
    );
  }

  Widget _card(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final accuracy = report.accuracy;

    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: colors.bgBase,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // A faint board pattern, turned, off the top right corner.
            Positioned(
              top: -120,
              right: -120,
              width: 560,
              height: 560,
              child: Transform.rotate(
                angle: 12 * math.pi / 180,
                child: Opacity(
                  opacity: 0.07,
                  child: CustomPaint(painter: _Checks(colors.textPrimary)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(88, 88, 88, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const LogoMark(size: 72),
                      const SizedBox(width: 16),
                      Text(
                        'Rooksight',
                        style: type.title.copyWith(fontSize: 36, letterSpacing: -0.36),
                      ),
                      const Spacer(),
                      Text(
                        'GAME REPORT',
                        style: type.body.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    report.context,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.body.copyWith(fontSize: 28, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: accuracy == null ? '—' : accuracy.toStringAsFixed(1),
                      children: [
                        TextSpan(
                          text: '%',
                          style: TextStyle(fontSize: 96, color: colors.focus),
                        ),
                      ],
                    ),
                    style: type.title.copyWith(
                      fontSize: 180,
                      height: 1,
                      letterSpacing: -9,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'accuracy',
                    style: type.body.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 32,
                    children: [
                      Expanded(
                        child: _MoveBox(
                          title: 'Best move',
                          titleColor: Color.lerp(colors.focus, colors.textPrimary, 0.3)!,
                          move: report.best,
                          orientation: report.orientation,
                        ),
                      ),
                      Expanded(
                        child: report.worst == null
                            ? const _NoBlunders()
                            : _MoveBox(
                                title: 'Worst blunder',
                                titleColor: colors.moveBlunder,
                                move: report.worst,
                                orientation: report.orientation,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // The verdict takes the room left, shrinking if it's long.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: SizedBox(
                          width: width - 176,
                          child: Text(
                            '“${report.verdict}”',
                            style: type.title.copyWith(
                              fontSize: 42,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.63,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.only(top: 28),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.border, width: 2)),
                    ),
                    child: DefaultTextStyle(
                      style: type.body.copyWith(fontSize: 24, color: colors.textTertiary),
                      child: Row(
                        children: [
                          Text(report.aiVerdict ? 'AI Coach verdict' : 'Game summary'),
                          const Spacer(),
                          Text('Rooksight · AI chess coach · ${reportDate(report.playedAt)}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A board with one move on it, and its label.
class _MoveBox extends StatelessWidget {
  const _MoveBox({
    required this.title,
    required this.titleColor,
    required this.move,
    required this.orientation,
  });

  final String title;
  final Color titleColor;
  final ReportMove? move;
  final Side orientation;

  static const _board = 340.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final move = this.move;
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 36),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          if (move == null)
            SizedBox.square(
              dimension: _board,
              child: ColoredBox(color: colors.bgElevated),
            )
          else
            RooksightStaticBoard(
              fen: move.fen,
              size: _board,
              lastMove: move.lastMove,
              orientation: orientation,
              coordinates: false,
              borderRadius: BorderRadius.circular(16),
              theme: BoardTheme.slate,
              shapes: {
                if ((move.quality, move.mark) case (final quality?, final mark?))
                  CustomShape(
                    orig: mark,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: QualityDisc(quality: quality, size: 20),
                    ),
                  ),
              },
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                title.toUpperCase(),
                style: type.body.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.76,
                  color: titleColor,
                ),
              ),
              Text(
                move?.label ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.mono.copyWith(fontSize: 44, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// In place of the worst blunder when there wasn't one (not in the design).
class _NoBlunders extends StatelessWidget {
  const _NoBlunders();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 36),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          SizedBox.square(
            dimension: _MoveBox._board,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.focus.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.check_rounded, size: 160, color: colors.focus),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                'WORST BLUNDER',
                style: type.body.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.76,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                'None',
                style: type.mono.copyWith(
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  color: Color.lerp(colors.focus, colors.textPrimary, 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A checkerboard, as the design's `repeating-conic-gradient`: 70px squares.
class _Checks extends CustomPainter {
  _Checks(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 70.0;
    final paint = Paint()..color = color;
    for (var row = 0; row * cell < size.height; row++) {
      for (var col = row.isEven ? 0 : 1; col * cell < size.width; col += 2) {
        canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Checks old) => old.color != color;
}

/// `28 Sep 2026`.
String reportDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
