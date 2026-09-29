import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_session.dart';
import 'captured_tray.dart';
import 'clock_view.dart';
import 'thinking_dots.dart';

/// A player's line above or below the board: avatar, name (with whose move
/// it is on the player's line), captured pieces and, on the player's line,
/// their clock.
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
    final captured = game.capturedBy(side);
    final advantage = game.materialAdvantage(side);
    final clock = session.clock;

    // Your row says whose move it is; Stockfish's shows when it's thinking.
    final yourTurn = isPlayer && !game.isOver && game.turn == side;
    final inCheck = yourTurn && game.checkedKing != null;
    final status = !isPlayer || game.isOver
        ? null
        : inCheck
        ? 'In check'
        : yourTurn
        ? 'Your move'
        : 'Stockfish to move';

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
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isPlayer ? 'You' : 'Stockfish',
                        style: type.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (status != null)
                        Text(
                          status,
                          style: type.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: inCheck
                                ? colors.coral
                                : yourTurn
                                ? colors.focus
                                : colors.textTertiary,
                          ),
                        ),
                      if (!isPlayer && session.engineThinking) const ThinkingDots(),
                    ],
                  ),
                  if (captured.isEmpty && advantage <= 0)
                    Text(
                      'No captures yet',
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
            // Only the player is timed; Stockfish takes the time it needs.
            if (clock != null && isPlayer) ClockView(clock: clock, side: side),
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
