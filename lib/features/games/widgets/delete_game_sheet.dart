import 'package:flutter/material.dart';

import '../../../core/storage/game_repository.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/move_wise_sheet.dart';
import '../games_screen.dart'
    show OutcomeBadge, endReasonLabel, movesLabel, opponentName, shortDate, timeControlLabel;

/// Asks before deleting [game], in a MoveWise sheet that shows which game it
/// is and what goes with it. True if the player chose Delete.
Future<bool> confirmDeleteGame(
  BuildContext context,
  GameRecord game, {
  required bool reduceMotion,
}) async {
  final deleted = await showMoveWiseSheet<bool>(
    context,
    reduceMotion: reduceMotion,
    builder: (context) => _DeleteGameSheet(game: game),
  );
  return deleted ?? false;
}

class _DeleteGameSheet extends StatelessWidget {
  const _DeleteGameSheet({required this.game});

  final GameRecord game;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.smAll);
    final buttonText = type.heading.copyWith(fontSize: 16);
    final details = [
      if (game.endReason != null) endReasonLabel(game.endReason!),
      movesLabel(game),
      ?timeControlLabel(game),
      shortDate(game.endedAt),
    ].join(' · ');

    return Semantics(
      container: true,
      label: 'Delete game',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s4,
        children: [
          Row(
            spacing: AppSpacing.s3,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.coral.withValues(alpha: 0.14),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(Icons.delete_outline_rounded, color: colors.coral),
              ),
              Expanded(child: Text('Delete this game?', style: type.title.copyWith(fontSize: 22))),
            ],
          ),
          // Which game: as it looks in the list.
          Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(color: colors.bgElevated, borderRadius: AppRadius.smAll),
            child: Row(
              spacing: AppSpacing.s3,
              children: [
                OutcomeBadge(outcome: game.outcome),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        'vs ${opponentName(game)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.heading.copyWith(fontSize: 16),
                      ),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.label.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Its review and AI notes are deleted too. It will no longer count in your stats. '
            '${game.source == GameSource.chesscom || game.source == GameSource.lichess ? 'Importing again may bring it back. ' : ''}'
            'This can’t be undone.',
            style: type.body.copyWith(color: colors.textSecondary),
          ),
          Row(
            spacing: AppSpacing.s3,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                    shape: buttonShape,
                    backgroundColor: colors.bgElevated,
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    textStyle: buttonText,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              // The design system's destructive button.
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                    shape: buttonShape,
                    foregroundColor: colors.coral,
                    side: BorderSide(color: colors.coral.withValues(alpha: 0.45)),
                    textStyle: buttonText,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('Delete game'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
