import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_session.dart';
import 'captured_tray.dart';
import 'clock_view.dart';
import 'thinking_dots.dart';

/// A player's line above or below the board: avatar, name (or status),
/// captured pieces and clock.
class PlayerRow extends StatelessWidget {
  const PlayerRow({super.key, required this.session, required this.side});

  final GameSession session;
  final Side side;

  static const height = 60.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final game = session.game;
    final config = session.config;
    final isPlayer = side == config.playerSide;
    final colourName = side == Side.white ? 'White' : 'Black';
    final captured = game.capturedBy(side);
    final advantage = game.materialAdvantage(side);
    final clock = session.clock;

    final inCheck = isPlayer && !game.isOver && game.turn == side && game.checkedKing != null;
    final title = !isPlayer
        ? 'Stockfish'
        : inCheck
        ? 'In check'
        : !game.isOver && game.turn == side
        ? 'Your move'
        : 'You';

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: Row(
          spacing: AppSpacing.s3,
          children: [
            _Avatar(isPlayer: isPlayer),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Row(
                    spacing: AppSpacing.s2,
                    children: [
                      Text(
                        title,
                        style: type.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: inCheck ? colors.coral : colors.textPrimary,
                        ),
                      ),
                      if (!isPlayer && session.engineThinking) const ThinkingDots(),
                    ],
                  ),
                  if (captured.isEmpty && advantage <= 0)
                    Text(
                      isPlayer ? colourName : '${config.level.elo} · $colourName',
                      style: type.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.textTertiary,
                      ),
                    )
                  else
                    CapturedTray(
                      captured: captured,
                      capturedSide: side.opposite,
                      advantage: advantage,
                      advantageColor: isPlayer
                          ? Color.lerp(colors.focus, colors.textPrimary, 0.3)
                          : colors.textSecondary,
                    ),
                ],
              ),
            ),
            if (clock != null) ClockView(clock: clock, side: side, isPlayer: isPlayer),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isPlayer});

  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPlayer ? colors.focus : colors.bgElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: isPlayer
          ? Text(
              'You',
              style: context.type.heading.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.onFocus,
              ),
            )
          : Icon(Icons.memory, size: 20, color: colors.textSecondary),
    );
  }
}
