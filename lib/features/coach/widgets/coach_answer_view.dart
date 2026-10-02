// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/board/rooksight_board.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/logo_mark.dart';
import '../domain/coach_agent.dart';
import '../domain/coach_move.dart';
import 'agent_steps.dart';

/// The coach's answer: headline, evidence, a habit to try, and the game move
/// that shows it.
class CoachAnswerView extends StatelessWidget {
  const CoachAnswerView({super.key, required this.answer});

  final CoachAnswer answer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final paragraph = type.body.copyWith(
      fontSize: 15,
      height: 23 / 15,
      color: Color.lerp(colors.textSecondary, colors.textPrimary, 0.6),
    );

    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Semantics(
        container: true,
        label: 'Coach answer',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s3,
          children: [
            Row(
              spacing: 10,
              children: [
                const LogoMark(size: 30),
                Expanded(
                  child: Text(
                    answer.headline ?? 'Here’s what I found',
                    style: type.heading.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
            Text(answer.body, style: paragraph),
            if (answer.tryThis case final tip?)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Try this: ',
                      style: TextStyle(color: colors.brass, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: tip),
                  ],
                ),
                style: paragraph,
              ),
            if (answer.move case final move?) CoachMoveCard(move: move),
          ],
        ),
      ),
    );
  }
}

/// A move from a game: the position after it, the move against Stockfish's
/// choice, and where it was played. Opens the review at that move.
class CoachMoveCard extends StatelessWidget {
  const CoachMoveCard({super.key, required this.move});

  final CoachMove move;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final played = '${move.label}${move.quality?.symbol ?? ''}';
    final best = move.best;
    // Only an error has a better move worth showing.
    final title = best != null && (move.quality?.isError ?? false) ? '$played → $best' : played;

    return Material(
      color: colors.bgRaised,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.review('${move.gameId}', ply: move.index + 1)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 10),
          child: Row(
            spacing: AppSpacing.s3,
            children: [
              RooksightStaticBoard(
                fen: move.fen,
                size: 52,
                lastMove: move.lastMove,
                orientation: move.orientation,
                coordinates: false,
                borderRadius: AppRadius.xsAll,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: type.mono.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'vs ${move.opponent} · ${playedWhen(move.playedAt, DateTime.now())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// `today`, `yesterday`, or `12 Sep`.
String playedWhen(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final days = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
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
  final label = '${date.day} ${months[date.month - 1]}';
  return date.year == now.year ? label : '$label ${date.year}';
}
